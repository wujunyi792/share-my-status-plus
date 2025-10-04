include "common.thrift"

namespace go share_my_status.cover

// 封面存在性查询请求
struct CoverExistsRequest {
    1: required string md5;
}

// 封面存在性查询响应
struct CoverExistsResponse {
    1: required common.BaseResponse base;
    2: optional bool exists;
    3: optional string coverHash;
}

// 封面上传请求
struct CoverUploadRequest {
    1: required string b64;  // base64编码的图片数据
}

// 封面上传响应
struct CoverUploadResponse {
    1: required common.BaseResponse base;
    2: optional string coverHash;
}

// 封面获取请求
struct CoverGetRequest {
    1: required string hash;
    2: optional i32 size = 256;  // 128, 256等
}

// 封面获取响应
struct CoverGetResponse {
    1: required common.BaseResponse base;
    2: optional binary data;
    3: optional string contentType;
}

// 封面服务定义
service CoverService {
    // 查询封面是否存在
    CoverExistsResponse CheckExists(1: CoverExistsRequest req) (api.get="/v1/cover/exists");
    
    // 上传封面
    CoverUploadResponse Upload(1: CoverUploadRequest req) (api.post="/v1/cover/upload");
    
    // 获取封面
    CoverGetResponse Get(1: CoverGetRequest req) (api.get="/v1/cover/{hash}");
}