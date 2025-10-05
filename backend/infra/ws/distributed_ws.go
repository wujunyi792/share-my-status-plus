package ws

import (
	"context"
	"encoding/json"
	"fmt"
	"share-my-status/model"
	"sync"
	"time"

	common "share-my-status/api/model/share_my_status/common"
	websocket_api "share-my-status/api/model/share_my_status/websocket"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/hertz-contrib/websocket"
	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

// WebSocketClient WebSocket客户端
type WebSocketClient struct {
	ID         string
	UserID     string
	Connection *websocket.Conn
	Send       chan []byte
	Hub        *DistributedWebSocketService
	LastPing   time.Time
}

// DistributedWebSocketService 分布式WebSocket服务
type DistributedWebSocketService struct {
	// 本地客户端连接管理
	localClients map[string]*WebSocketClient // clientID -> client
	clientsMux   sync.RWMutex

	// 用户订阅管理
	userSubscriptions map[string]map[string]bool // userID -> connectionID -> true
	subscriptionsMux  sync.RWMutex

	// Redis客户端
	redisClient *redis.Client

	// 数据库连接
	db *gorm.DB

	// 节点ID（用于区分不同实例）
	nodeID string

	// Redis Pub/Sub
	pubSub *redis.PubSub

	// 停止信号
	stopChan chan struct{}
}

// WebSocketMessage 分布式WebSocket消息
type WebSocketMessage struct {
	Type      string                 `json:"type"`
	NodeID    string                 `json:"nodeId"`
	UserID    string                 `json:"userId"`
	ClientID  string                 `json:"clientId,omitempty"`
	Data      map[string]interface{} `json:"data"`
	Timestamp int64                  `json:"timestamp"`
}

// InitDistributedWebSocketService 创建分布式WebSocket服务
func InitDistributedWebSocketService(redisClient *redis.Client, db *gorm.DB) *DistributedWebSocketService {
	nodeID := fmt.Sprintf("node_%d", time.Now().UnixNano())

	service := &DistributedWebSocketService{
		localClients:      make(map[string]*WebSocketClient),
		userSubscriptions: make(map[string]map[string]bool),
		redisClient:       redisClient,
		db:                db,
		nodeID:            nodeID,
		stopChan:          make(chan struct{}),
	}

	// 启动Redis Pub/Sub监听
	go service.startRedisListener()

	logrus.Infof("Distributed WebSocket service started with node ID: %s", nodeID)
	return service
}

var distributedUpgrader = websocket.HertzUpgrader{} // 使用默认选项

// Connect 处理WebSocket连接
func (ws *DistributedWebSocketService) Connect(ctx context.Context, c *app.RequestContext, userID string) error {
	logrus.Infof("WebSocket connection request for user: %s", userID)

	err := distributedUpgrader.Upgrade(c, func(conn *websocket.Conn) {
		// 创建客户端
		clientID := fmt.Sprintf("%s_%s_%d", ws.nodeID, userID, time.Now().UnixNano())
		client := &WebSocketClient{
			ID:         clientID,
			UserID:     userID,
			Connection: conn,
			Send:       make(chan []byte, 256),
			Hub:        nil, // 分布式模式下不需要Hub
			LastPing:   time.Now(),
		}

		// 注册本地客户端
		ws.registerLocalClient(client)

		// 启动读写协程
		go ws.clientWritePump(client)
		go ws.clientReadPump(client)

		// 发送欢迎消息
		welcomeMsg := &websocket_api.WSMessage{
			Type:      websocket_api.MessageType_PONG,
			Timestamp: time.Now().UnixMilli(),
		}
		ws.sendMessageToClient(client, welcomeMsg)

		logrus.Infof("WebSocket client connected: %s (user: %s)", clientID, userID)
	})

	if err != nil {
		logrus.Errorf("Failed to upgrade WebSocket connection: %v", err)
		return err
	}

	return nil
}

// registerLocalClient 注册本地客户端
func (ws *DistributedWebSocketService) registerLocalClient(client *WebSocketClient) {
	ws.clientsMux.Lock()
	defer ws.clientsMux.Unlock()

	ws.localClients[client.ID] = client

	// 添加到用户订阅
	ws.subscriptionsMux.Lock()
	defer ws.subscriptionsMux.Unlock()

	if ws.userSubscriptions[client.UserID] == nil {
		ws.userSubscriptions[client.UserID] = make(map[string]bool)
	}
	ws.userSubscriptions[client.UserID][client.ID] = true
}

// unregisterLocalClient 注销本地客户端
func (ws *DistributedWebSocketService) unregisterLocalClient(client *WebSocketClient) {
	ws.clientsMux.Lock()
	defer ws.clientsMux.Unlock()

	delete(ws.localClients, client.ID)

	// 从用户订阅中移除
	ws.subscriptionsMux.Lock()
	defer ws.subscriptionsMux.Unlock()

	if userSubs, exists := ws.userSubscriptions[client.UserID]; exists {
		delete(userSubs, client.ID)
		if len(userSubs) == 0 {
			delete(ws.userSubscriptions, client.UserID)
		}
	}

	close(client.Send)
}

// BroadcastToUser 向指定用户的所有连接广播消息
func (ws *DistributedWebSocketService) BroadcastToUser(userID string, message *websocket_api.WSMessage) {
	// 发布到Redis，让所有节点都能收到
	wsMessage := &WebSocketMessage{
		Type:   "broadcast",
		NodeID: ws.nodeID,
		UserID: userID,
		Data: map[string]interface{}{
			"message": message,
		},
		Timestamp: time.Now().UnixMilli(),
	}

	ws.publishToRedis(wsMessage)
}

// BroadcastStatusUpdate 广播状态更新
func (ws *DistributedWebSocketService) BroadcastStatusUpdate(userID string, snapshot *common.StatusSnapshot) {
	updateMsg := &websocket_api.WSMessage{
		Type:      websocket_api.MessageType_STATUS_UPDATE,
		Snapshot:  snapshot,
		Timestamp: time.Now().UnixMilli(),
	}

	ws.BroadcastToUser(userID, updateMsg)
}

// publishToRedis 发布消息到Redis
func (ws *DistributedWebSocketService) publishToRedis(message *WebSocketMessage) {
	messageBytes, err := json.Marshal(message)
	if err != nil {
		logrus.Errorf("Failed to marshal WebSocket message: %v", err)
		return
	}

	ctx := context.Background()
	err = ws.redisClient.Publish(ctx, "websocket:broadcast", messageBytes).Err()
	if err != nil {
		logrus.Errorf("Failed to publish message to Redis: %v", err)
	}
}

// startRedisListener 启动Redis监听器
func (ws *DistributedWebSocketService) startRedisListener() {
	ctx := context.Background()

	// 订阅Redis频道
	ws.pubSub = ws.redisClient.Subscribe(ctx, "websocket:broadcast")
	defer ws.pubSub.Close()

	// 启动消息处理协程
	go func() {
		for {
			select {
			case <-ws.stopChan:
				logrus.Info("Stopping Redis listener")
				return
			default:
				msg, err := ws.pubSub.ReceiveMessage(ctx)
				if err != nil {
					logrus.Errorf("Failed to receive message from Redis: %v", err)
					time.Sleep(time.Second)
					continue
				}

				ws.handleRedisMessage(msg.Payload)
			}
		}
	}()

	logrus.Info("Redis listener started")
}

// handleRedisMessage 处理Redis消息
func (ws *DistributedWebSocketService) handleRedisMessage(payload string) {
	var message WebSocketMessage
	err := json.Unmarshal([]byte(payload), &message)
	if err != nil {
		logrus.Errorf("Failed to unmarshal Redis message: %v", err)
		return
	}

	// 忽略自己发布的消息
	if message.NodeID == ws.nodeID {
		return
	}

	switch message.Type {
	case "broadcast":
		ws.handleBroadcastMessage(&message)
	case "disconnect":
		ws.handleDisconnectMessage(&message)
	default:
		logrus.Warnf("Unknown message type: %s", message.Type)
	}
}

// handleBroadcastMessage 处理广播消息
func (ws *DistributedWebSocketService) handleBroadcastMessage(message *WebSocketMessage) {
	userID := message.UserID

	// 检查本地是否有该用户的连接
	ws.subscriptionsMux.RLock()
	userSubs, exists := ws.userSubscriptions[userID]
	ws.subscriptionsMux.RUnlock()

	if !exists || len(userSubs) == 0 {
		return // 本地没有该用户的连接
	}

	// 获取消息数据
	messageData, ok := message.Data["message"].(map[string]interface{})
	if !ok {
		logrus.Errorf("Invalid message data format")
		return
	}

	// 转换为WebSocket消息
	wsMsg := &websocket_api.WSMessage{}
	if msgType, ok := messageData["type"].(float64); ok {
		wsMsg.Type = websocket_api.MessageType(int32(msgType))
	}
	if timestamp, ok := messageData["timestamp"].(float64); ok {
		wsMsg.Timestamp = int64(timestamp)
	}
	if snapshotData, ok := messageData["snapshot"].(map[string]interface{}); ok {
		// 将Redis消息中的snapshot数据转换为common.StatusSnapshot
		snapshot, err := convertMapToStatusSnapshot(snapshotData)
		if err != nil {
			logrus.Errorf("Failed to convert snapshot from Redis message: %v", err)
			return
		}
		wsMsg.Snapshot = snapshot
	}

	// 向本地连接发送消息
	ws.clientsMux.RLock()
	for clientID := range userSubs {
		if client, exists := ws.localClients[clientID]; exists {
			ws.sendMessageToClient(client, wsMsg)
		}
	}
	ws.clientsMux.RUnlock()
}

// handleDisconnectMessage 处理断开连接消息
func (ws *DistributedWebSocketService) handleDisconnectMessage(message *WebSocketMessage) {
	// 处理其他节点发送的断开连接消息
	logrus.Infof("Received disconnect message for user: %s", message.UserID)
}

// sendMessageToClient 发送消息给客户端
func (ws *DistributedWebSocketService) sendMessageToClient(client *WebSocketClient, message *websocket_api.WSMessage) {
	messageBytes, err := json.Marshal(message)
	if err != nil {
		logrus.Errorf("Failed to marshal message: %v", err)
		return
	}

	select {
	case client.Send <- messageBytes:
	default:
		logrus.Warnf("Client %s send channel is full, dropping message", client.ID)
	}
}

// clientReadPump 客户端读取协程
func (ws *DistributedWebSocketService) clientReadPump(client *WebSocketClient) {
	defer func() {
		ws.unregisterLocalClient(client)
		client.Connection.Close()
	}()

	// 设置读取超时
	client.Connection.SetReadDeadline(time.Now().Add(60 * time.Second))
	client.Connection.SetPongHandler(func(string) error {
		client.LastPing = time.Now()
		client.Connection.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		mt, message, err := client.Connection.ReadMessage()
		if err != nil {
			logrus.Errorf("WebSocket read error: %v", err)
			break
		}

		// 只处理文本消息
		if mt == websocket.TextMessage {
			var msg websocket_api.WSMessage
			if err := json.Unmarshal(message, &msg); err != nil {
				logrus.Errorf("Failed to unmarshal WebSocket message: %v", err)
				continue
			}

			// 处理消息
			ws.handleClientMessage(client, &msg)
		}
	}
}

// clientWritePump 客户端写入协程
func (ws *DistributedWebSocketService) clientWritePump(client *WebSocketClient) {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		client.Connection.Close()
	}()

	for {
		select {
		case message, ok := <-client.Send:
			client.Connection.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				client.Connection.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := client.Connection.WriteMessage(websocket.TextMessage, message); err != nil {
				logrus.Errorf("Failed to write WebSocket message: %v", err)
				return
			}

		case <-ticker.C:
			client.Connection.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := client.Connection.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// handleClientMessage 处理客户端消息
func (ws *DistributedWebSocketService) handleClientMessage(client *WebSocketClient, msg *websocket_api.WSMessage) {
	switch msg.Type {
	case websocket_api.MessageType_PING:
		// 回复pong
		pongMsg := &websocket_api.WSMessage{
			Type:      websocket_api.MessageType_PONG,
			Timestamp: time.Now().UnixMilli(),
		}
		ws.sendMessageToClient(client, pongMsg)

	case websocket_api.MessageType_SNAPSHOT:
		// 请求当前状态快照
		ws.sendCurrentSnapshot(client)

	default:
		logrus.Warnf("Unknown WebSocket message type: %d", msg.Type)
	}
}

// sendCurrentSnapshot 发送当前状态快照
func (ws *DistributedWebSocketService) sendCurrentSnapshot(client *WebSocketClient) {
	// 从数据库获取当前状态
	currentState, err := ws.getCurrentState(context.Background(), client.UserID)
	if err != nil {
		logrus.Errorf("Failed to get current state for WebSocket client %s: %v", client.ID, err)
		errorMsg := &websocket_api.WSMessage{
			Type:      websocket_api.MessageType_ERROR,
			Timestamp: time.Now().UnixMilli(),
		}
		ws.sendMessageToClient(client, errorMsg)
		return
	}

	// 发送快照消息
	snapshotMsg := &websocket_api.WSMessage{
		Type:      websocket_api.MessageType_SNAPSHOT,
		Snapshot:  currentState,
		Timestamp: time.Now().UnixMilli(),
	}

	ws.sendMessageToClient(client, snapshotMsg)
}

// getCurrentState 获取用户当前状态
func (ws *DistributedWebSocketService) getCurrentState(ctx context.Context, userID string) (*common.StatusSnapshot, error) {
	// 直接查询数据库获取当前状态
	var currentState model.CurrentState
	err := ws.db.WithContext(ctx).Where("open_id = ?", userID).First(&currentState).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// 返回空快照
			return &common.StatusSnapshot{
				LastUpdateTs: time.Now().UnixMilli(),
			}, nil
		}
		return nil, err
	}

	// 获取快照数据
	snapshotData := currentState.Snapshot.Data()
	return &snapshotData, nil
}

// convertMapToStatusSnapshot 将map[string]interface{}转换为common.StatusSnapshot
func convertMapToStatusSnapshot(data map[string]interface{}) (*common.StatusSnapshot, error) {
	snapshot := &common.StatusSnapshot{}

	// 转换最后更新时间
	if lastUpdateTs, ok := data["lastUpdateTs"].(float64); ok {
		snapshot.LastUpdateTs = int64(lastUpdateTs)
	}

	// 转换系统信息
	if systemData, ok := data["system"].(map[string]interface{}); ok {
		system := &common.System{}
		if batteryPct, ok := systemData["batteryPct"].(float64); ok {
			system.BatteryPct = &batteryPct
		}
		if charging, ok := systemData["charging"].(bool); ok {
			system.Charging = &charging
		}
		if cpuPct, ok := systemData["cpuPct"].(float64); ok {
			system.CpuPct = &cpuPct
		}
		if memoryPct, ok := systemData["memoryPct"].(float64); ok {
			system.MemoryPct = &memoryPct
		}
		snapshot.System = system
	}

	// 转换音乐信息
	if musicData, ok := data["music"].(map[string]interface{}); ok {
		music := &common.Music{}
		if title, ok := musicData["title"].(string); ok {
			music.Title = &title
		}
		if artist, ok := musicData["artist"].(string); ok {
			music.Artist = &artist
		}
		if album, ok := musicData["album"].(string); ok {
			music.Album = &album
		}
		if coverHash, ok := musicData["coverHash"].(string); ok {
			music.CoverHash = &coverHash
		}
		snapshot.Music = music
	}

	// 转换活动信息
	if activityData, ok := data["activity"].(map[string]interface{}); ok {
		if label, ok := activityData["label"].(string); ok {
			activity := &common.Activity{
				Label: label,
			}
			snapshot.Activity = activity
		}
	}

	return snapshot, nil
}

// GetConnectedUsersCount 获取连接的用户数量
func (ws *DistributedWebSocketService) GetConnectedUsersCount() int {
	ws.subscriptionsMux.RLock()
	defer ws.subscriptionsMux.RUnlock()
	return len(ws.userSubscriptions)
}

// GetLocalClientsCount 获取本地客户端数量
func (ws *DistributedWebSocketService) GetLocalClientsCount() int {
	ws.clientsMux.RLock()
	defer ws.clientsMux.RUnlock()
	return len(ws.localClients)
}

// Shutdown 关闭服务
func (ws *DistributedWebSocketService) Shutdown() {
	// 停止Redis监听器
	close(ws.stopChan)

	// 关闭所有本地连接
	ws.clientsMux.Lock()
	for _, client := range ws.localClients {
		client.Connection.Close()
	}
	ws.clientsMux.Unlock()

	logrus.Info("Distributed WebSocket service shutdown")
}
