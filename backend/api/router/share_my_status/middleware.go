package share_my_status

import (
	"share-my-status/api/middleware"

	"github.com/cloudwego/hertz/pkg/app"
)

func rootMw() []app.HandlerFunc {
	return nil
}

func _v1Mw() []app.HandlerFunc {
	return nil
}

func _connectMw() []app.HandlerFunc {
	// WebSocket连接需要Sharing Key认证
	return []app.HandlerFunc{
		middleware.SharingKeyAuth(),
	}
}

func _coverMw() []app.HandlerFunc {
	return nil
}

func _checkexistsMw() []app.HandlerFunc {
	// 封面存在性检查需要Sharing Key认证
	return []app.HandlerFunc{
		middleware.SecretKeyAuth(),
	}
}

func _getMw() []app.HandlerFunc {
	// 封面获取需要Sharing Key认证
	return []app.HandlerFunc{
		middleware.SharingKeyAuth(),
	}
}

func _uploadMw() []app.HandlerFunc {
	// 封面上传需要Secret Key认证
	return []app.HandlerFunc{
		middleware.SecretKeyAuth(),
	}
}

func _stateMw() []app.HandlerFunc {
	return nil
}

func _querystateMw() []app.HandlerFunc {
	// 状态查询需要Sharing Key认证
	return []app.HandlerFunc{
		middleware.SharingKeyAuth(),
	}
}

func _batchreportMw() []app.HandlerFunc {
	// 状态上报需要Secret Key认证
	return []app.HandlerFunc{
		middleware.SecretKeyAuth(),
	}
}

func _statsMw() []app.HandlerFunc {
	return nil
}

func _querystatsMw() []app.HandlerFunc {
	// 统计查询需要Secret Key认证
	return []app.HandlerFunc{
		middleware.SharingKeyAuth(),
	}
}

func _apiMw() []app.HandlerFunc {
	// your code...
	return nil
}

func _sMw() []app.HandlerFunc {
	// your code...
	return nil
}

func _redirectMw() []app.HandlerFunc {
	// your code...
	return nil
}
