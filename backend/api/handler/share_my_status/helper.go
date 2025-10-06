package share_my_status

import (
	"reflect"

	common "share-my-status/api/model/share_my_status/common"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/protocol/consts"
)

// ResponseHelper 响应助手结构体
type ResponseHelper struct{}

// NewResponseHelper 创建响应助手实例
func NewResponseHelper() *ResponseHelper {
	return &ResponseHelper{}
}

// SendErrorResponse 发送错误响应
// responseType: 响应结构体的类型，例如 &state.BatchReportResponse{}
// code: HTTP状态码
// message: 错误消息
func (h *ResponseHelper) SendErrorResponse(c *app.RequestContext, responseType any, code int, message string) {
	// 使用反射创建新的响应实例
	responseValue := reflect.New(reflect.TypeOf(responseType).Elem())
	response := responseValue.Interface()

	// 查找Base字段并设置值
	h.setBaseField(response, int32(code), message)

	// 根据HTTP状态码发送响应
	switch code {
	case 400:
		c.JSON(consts.StatusOK, response)
	case 401:
		c.JSON(consts.StatusOK, response)
	case 404:
		c.JSON(consts.StatusOK, response)
	case 500:
		c.JSON(consts.StatusOK, response)
	default:
		c.JSON(code, response)
	}
}

// SendSuccessResponse 发送成功响应
// 如果response的Base字段为nil，则填充成功状态(code=0)
// 否则按照现有的错误码和错误信息填充
// 最终HTTP响应码始终是200
func (h *ResponseHelper) SendSuccessResponse(c *app.RequestContext, response any) {
	// 检查并处理Base字段
	h.ensureBaseField(response)
	c.JSON(consts.StatusOK, response)
}

// ensureBaseField 确保Base字段被正确填充
// 如果Base字段为nil，则填充成功状态(code=0, message="success")
// 如果Base字段已存在，则保持原有的错误码和错误信息
func (h *ResponseHelper) ensureBaseField(response any) {
	responseValue := reflect.ValueOf(response).Elem()
	responseType := responseValue.Type()

	// 查找Base字段
	for i := 0; i < responseType.NumField(); i++ {
		field := responseType.Field(i)
		fieldValue := responseValue.Field(i)

		// 如果字段名是"Base"且类型是*common.BaseResponse
		if field.Name == "Base" && field.Type == reflect.TypeOf((*common.BaseResponse)(nil)) {
			// 如果Base字段为nil，则填充成功状态
			if fieldValue.IsNil() {
				successMessage := "success"
				baseResp := &common.BaseResponse{
					Code:    0,
					Message: &successMessage,
				}
				fieldValue.Set(reflect.ValueOf(baseResp))
			}
			// 如果Base字段已存在，则保持原有值不变
			break
		}
	}
}

// setBaseField 使用反射设置响应结构体的Base字段
func (h *ResponseHelper) setBaseField(response any, code int32, message string) {
	responseValue := reflect.ValueOf(response).Elem()
	responseType := responseValue.Type()

	// 查找Base字段
	for i := 0; i < responseType.NumField(); i++ {
		field := responseType.Field(i)
		fieldValue := responseValue.Field(i)

		// 如果字段名是"Base"且类型是*common.BaseResponse
		if field.Name == "Base" && field.Type == reflect.TypeOf((*common.BaseResponse)(nil)) {
			// 创建BaseResponse实例
			baseResp := &common.BaseResponse{
				Code:    code,
				Message: &message,
			}

			// 设置字段值
			fieldValue.Set(reflect.ValueOf(baseResp))
			break
		}
	}
}
