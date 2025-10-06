include "common.thrift"

namespace go share_my_status.redirect

// 链接跳转请求
struct RedirectRequest {
    1: required string sharing_key(api.path="sharingKey");
    2: string r(api.query="r")
}

// 链接跳转响应
struct RedirectResponse {
    1: required common.BaseResponse base;
}
