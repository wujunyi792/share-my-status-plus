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
func (h *ResponseHelper) SendErrorResponse(c *app.RequestContext, responseType interface{}, code int, message string) {
	// 使用反射创建新的响应实例
	responseValue := reflect.New(reflect.TypeOf(responseType).Elem())
	response := responseValue.Interface()

	// 查找Base字段并设置值
	h.setBaseField(response, int32(code), message)

	// 根据HTTP状态码发送响应
	switch code {
	case 400:
		c.JSON(consts.StatusBadRequest, response)
	case 401:
		c.JSON(consts.StatusUnauthorized, response)
	case 404:
		c.JSON(consts.StatusNotFound, response)
	case 500:
		c.JSON(consts.StatusInternalServerError, response)
	default:
		c.JSON(code, response)
	}
}

// SendSuccessResponse 发送成功响应
func (h *ResponseHelper) SendSuccessResponse(c *app.RequestContext, response interface{}) {
	c.JSON(consts.StatusOK, response)
}

// SendSuccessResponseWithAutoBase 发送成功响应并自动填充Base字段
// responseType: 响应结构体的类型，例如 &state.BatchReportResponse{}
// data: 响应数据，可以是nil或者包含具体数据的结构体
// message: 成功消息，默认为"success"
func (h *ResponseHelper) SendSuccessResponseWithAutoBase(c *app.RequestContext, responseType interface{}, data interface{}, message ...string) {
	successMessage := "success"
	if len(message) > 0 && message[0] != "" {
		successMessage = message[0]
	}

	// 使用反射创建新的响应实例
	responseValue := reflect.New(reflect.TypeOf(responseType).Elem())
	response := responseValue.Interface()

	// 设置Base字段
	h.setBaseField(response, 0, successMessage)

	// 如果提供了数据，尝试复制数据到响应结构体
	if data != nil {
		h.copyDataToResponse(response, data)
	}

	c.JSON(consts.StatusOK, response)
}

// copyDataToResponse 将数据复制到响应结构体中（跳过Base字段）
func (h *ResponseHelper) copyDataToResponse(response interface{}, data interface{}) {
	responseValue := reflect.ValueOf(response).Elem()
	responseType := responseValue.Type()
	dataValue := reflect.ValueOf(data)

	// 如果data是nil，直接返回
	if !dataValue.IsValid() || dataValue.IsNil() {
		return
	}

	// 如果data是指针，获取其指向的值
	if dataValue.Kind() == reflect.Ptr {
		dataValue = dataValue.Elem()
	}

	// 如果data是结构体，复制字段
	if dataValue.Kind() == reflect.Struct {
		// 遍历响应结构体的所有字段
		for i := 0; i < responseType.NumField(); i++ {
			field := responseType.Field(i)
			fieldValue := responseValue.Field(i)

			// 跳过Base字段
			if field.Name == "Base" {
				continue
			}

			// 在数据中查找同名字段
			if dataField := dataValue.FieldByName(field.Name); dataField.IsValid() && dataField.CanInterface() {
				if fieldValue.CanSet() {
					// 类型匹配时直接赋值
					if dataField.Type().AssignableTo(fieldValue.Type()) {
						fieldValue.Set(dataField)
					} else if dataField.Type().ConvertibleTo(fieldValue.Type()) {
						fieldValue.Set(dataField.Convert(fieldValue.Type()))
					}
				}
			}
		}
	} else {
		// 如果data不是结构体，尝试找到第一个非Base字段进行赋值
		for i := 0; i < responseType.NumField(); i++ {
			field := responseType.Field(i)
			fieldValue := responseValue.Field(i)

			// 跳过Base字段
			if field.Name == "Base" {
				continue
			}

			// 找到第一个非Base字段，尝试赋值
			if fieldValue.CanSet() {
				if dataValue.Type().AssignableTo(fieldValue.Type()) {
					fieldValue.Set(dataValue)
				} else if dataValue.Type().ConvertibleTo(fieldValue.Type()) {
					fieldValue.Set(dataValue.Convert(fieldValue.Type()))
				}
				break
			}
		}
	}
}

// setBaseField 使用反射设置响应结构体的Base字段
func (h *ResponseHelper) setBaseField(response interface{}, code int32, message string) {
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

// CreateErrorResponse 创建错误响应结构体（不发送）
// responseType: 响应结构体的类型，例如 &state.BatchReportResponse{}
// code: 错误代码
// message: 错误消息
func (h *ResponseHelper) CreateErrorResponse(responseType interface{}, code int32, message string) interface{} {
	// 使用反射创建新的响应实例
	responseValue := reflect.New(reflect.TypeOf(responseType).Elem())
	response := responseValue.Interface()

	// 设置Base字段
	h.setBaseField(response, code, message)

	return response
}

// CreateSuccessResponse 创建成功响应结构体（不发送）
// responseType: 响应结构体的类型，例如 &state.BatchReportResponse{}
// message: 成功消息，默认为"success"
func (h *ResponseHelper) CreateSuccessResponse(responseType interface{}, message ...string) interface{} {
	successMessage := "success"
	if len(message) > 0 && message[0] != "" {
		successMessage = message[0]
	}

	// 使用反射创建新的响应实例
	responseValue := reflect.New(reflect.TypeOf(responseType).Elem())
	response := responseValue.Interface()

	// 设置Base字段
	h.setBaseField(response, 0, successMessage)

	return response
}
