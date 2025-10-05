package service

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	common "share-my-status/api/model/share_my_status/common"
	websocket_api "share-my-status/api/model/share_my_status/websocket"
	"share-my-status/internal/database"
	"share-my-status/internal/model"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/gorilla/websocket"
	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

// WebSocketService WebSocket服务
type WebSocketService struct {
	// 客户端连接管理
	clients    map[string]*WebSocketClient
	clientsMux sync.RWMutex

	// 用户订阅管理
	userSubscriptions map[string]map[string]bool // userID -> connectionID -> true
	subscriptionsMux  sync.RWMutex
}

// WebSocketClient WebSocket客户端
type WebSocketClient struct {
	ID         string
	UserID     string
	Connection *websocket.Conn
	Send       chan []byte
	Hub        *WebSocketService
	LastPing   time.Time
}

// NewWebSocketService 创建WebSocket服务
func NewWebSocketService() *WebSocketService {
	return &WebSocketService{
		clients:           make(map[string]*WebSocketClient),
		userSubscriptions: make(map[string]map[string]bool),
	}
}

// Connect 处理WebSocket连接
func (ws *WebSocketService) Connect(ctx context.Context, c *app.RequestContext, userID string) error {
	// 注意：这里简化了WebSocket升级过程
	// 在实际生产环境中，可能需要使用Hertz的WebSocket支持或自定义实现

	// 暂时返回一个模拟的连接，实际应该实现真正的WebSocket升级
	logrus.Infof("WebSocket connection request for user: %s", userID)

	// 这里应该实现真正的WebSocket升级逻辑
	// 由于Hertz和gorilla/websocket的兼容性问题，这里先简化处理
	return fmt.Errorf("WebSocket upgrade not implemented yet")
}

// registerClient 注册客户端
func (ws *WebSocketService) registerClient(client *WebSocketClient) {
	ws.clientsMux.Lock()
	defer ws.clientsMux.Unlock()

	ws.clients[client.ID] = client

	// 添加到用户订阅
	ws.subscriptionsMux.Lock()
	defer ws.subscriptionsMux.Unlock()

	if ws.userSubscriptions[client.UserID] == nil {
		ws.userSubscriptions[client.UserID] = make(map[string]bool)
	}
	ws.userSubscriptions[client.UserID][client.ID] = true
}

// unregisterClient 注销客户端
func (ws *WebSocketService) unregisterClient(client *WebSocketClient) {
	ws.clientsMux.Lock()
	defer ws.clientsMux.Unlock()

	delete(ws.clients, client.ID)

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

// BroadcastToUser 向指定用户广播消息
func (ws *WebSocketService) BroadcastToUser(userID string, message *websocket_api.WSMessage) {
	ws.subscriptionsMux.RLock()
	userSubs, exists := ws.userSubscriptions[userID]
	if !exists {
		ws.subscriptionsMux.RUnlock()
		return
	}

	clientIDs := make([]string, 0, len(userSubs))
	for clientID := range userSubs {
		clientIDs = append(clientIDs, clientID)
	}
	ws.subscriptionsMux.RUnlock()

	// 向所有该用户的连接发送消息
	for _, clientID := range clientIDs {
		ws.clientsMux.RLock()
		client, exists := ws.clients[clientID]
		ws.clientsMux.RUnlock()

		if exists {
			ws.sendMessageToClient(client, message)
		}
	}
}

// sendMessageToClient 向客户端发送消息
func (ws *WebSocketService) sendMessageToClient(client *WebSocketClient, message *websocket_api.WSMessage) {
	data, err := json.Marshal(message)
	if err != nil {
		logrus.Errorf("Failed to marshal WebSocket message: %v", err)
		return
	}

	select {
	case client.Send <- data:
	default:
		// 发送缓冲区满，关闭连接
		ws.unregisterClient(client)
		client.Connection.Close()
	}
}

// readPump 读取WebSocket消息
func (c *WebSocketClient) readPump() {
	defer func() {
		c.Hub.unregisterClient(c)
		c.Connection.Close()
	}()

	// 设置读取超时
	c.Connection.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.Connection.SetPongHandler(func(string) error {
		c.LastPing = time.Now()
		c.Connection.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		var msg websocket_api.WSMessage
		err := c.Connection.ReadJSON(&msg)
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				logrus.Errorf("WebSocket error: %v", err)
			}
			break
		}

		// 处理消息
		c.handleMessage(&msg)
	}
}

// writePump 写入WebSocket消息
func (c *WebSocketClient) writePump() {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		c.Connection.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			c.Connection.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.Connection.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.Connection.WriteMessage(websocket.TextMessage, message); err != nil {
				logrus.Errorf("Failed to write WebSocket message: %v", err)
				return
			}

		case <-ticker.C:
			c.Connection.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.Connection.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// handleMessage 处理WebSocket消息
func (c *WebSocketClient) handleMessage(msg *websocket_api.WSMessage) {
	switch msg.Type {
	case websocket_api.MessageType_PING:
		// 回复PONG
		pongMsg := &websocket_api.WSMessage{
			Type:      websocket_api.MessageType_PONG,
			ID:        msg.ID,
			Timestamp: time.Now().UnixMilli(),
		}
		c.Hub.sendMessageToClient(c, pongMsg)

	case websocket_api.MessageType_SNAPSHOT:
		// 请求当前状态快照
		c.sendCurrentSnapshot()

	default:
		logrus.Warnf("Unknown WebSocket message type: %d", msg.Type)
	}
}

// sendCurrentSnapshot 发送当前状态快照
func (c *WebSocketClient) sendCurrentSnapshot() {
	// 获取用户当前状态
	var currentState model.CurrentState
	err := database.GetDB().Where("open_id = ?", c.UserID).First(&currentState).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// 没有状态数据
			emptyMsg := &websocket_api.WSMessage{
				Type:      websocket_api.MessageType_SNAPSHOT,
				Timestamp: time.Now().UnixMilli(),
			}
			c.Hub.sendMessageToClient(c, emptyMsg)
			return
		}

		// 数据库错误
		errorMsg := &websocket_api.WSMessage{
			Type:      websocket_api.MessageType_ERROR,
			Error:     &[]string{"Failed to get current state"}[0],
			Timestamp: time.Now().UnixMilli(),
		}
		c.Hub.sendMessageToClient(c, errorMsg)
		return
	}

	// 转换为API格式
	stateService := NewStateService()
	snapshot, err := stateService.convertToStatusSnapshot(currentState.Snapshot)
	if err != nil {
		errorMsg := &websocket_api.WSMessage{
			Type:      websocket_api.MessageType_ERROR,
			Error:     &[]string{"Failed to convert snapshot"}[0],
			Timestamp: time.Now().UnixMilli(),
		}
		c.Hub.sendMessageToClient(c, errorMsg)
		return
	}

	// 发送快照消息
	snapshotMsg := &websocket_api.WSMessage{
		Type:      websocket_api.MessageType_SNAPSHOT,
		Snapshot:  snapshot,
		Timestamp: time.Now().UnixMilli(),
	}
	c.Hub.sendMessageToClient(c, snapshotMsg)
}

// BroadcastStatusUpdate 广播状态更新
func (ws *WebSocketService) BroadcastStatusUpdate(userID string, snapshot *common.StatusSnapshot) {
	updateMsg := &websocket_api.WSMessage{
		Type:      websocket_api.MessageType_STATUS_UPDATE,
		Snapshot:  snapshot,
		Timestamp: time.Now().UnixMilli(),
	}

	ws.BroadcastToUser(userID, updateMsg)
}

// GetConnectedUsers 获取当前连接的用户数
func (ws *WebSocketService) GetConnectedUsers() int {
	ws.subscriptionsMux.RLock()
	defer ws.subscriptionsMux.RUnlock()
	return len(ws.userSubscriptions)
}

// GetTotalConnections 获取总连接数
func (ws *WebSocketService) GetTotalConnections() int {
	ws.clientsMux.RLock()
	defer ws.clientsMux.RUnlock()
	return len(ws.clients)
}
