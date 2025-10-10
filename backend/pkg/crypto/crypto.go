package crypto

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
)

// PKCS7Padding PKCS7填充
func PKCS7Padding(text []byte, blockSize int) []byte {
	// 计算待填充的长度
	padding := blockSize - len(text)%blockSize
	var paddingText []byte
	if padding == 0 {
		// 已对齐，填充一整块数据，每个数据为 blockSize
		paddingText = bytes.Repeat([]byte{byte(blockSize)}, blockSize)
	} else {
		// 未对齐 填充 padding 个数据，每个数据为 padding
		paddingText = bytes.Repeat([]byte{byte(padding)}, padding)
	}
	return append(text, paddingText...)
}

// UnPKCS7Padding 去除PKCS7填充
func UnPKCS7Padding(text []byte) []byte {
	// 取出填充的数据 以此来获得填充数据长度
	unPadding := int(text[len(text)-1])
	return text[:(len(text) - unPadding)]
}

// CBCEncrypt CBC模式加密
func CBCEncrypt(text []byte, key []byte, iv []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	// 填充
	padText := PKCS7Padding(text, block.BlockSize())

	blockMode := cipher.NewCBCEncrypter(block, iv)

	// 加密
	result := make([]byte, len(padText))
	blockMode.CryptBlocks(result, padText)
	// 返回密文
	return result, nil
}

// CBCDecrypt CBC模式解密
func CBCDecrypt(encrypter []byte, key []byte, iv []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	blockMode := cipher.NewCBCDecrypter(block, iv)
	result := make([]byte, len(encrypter))
	blockMode.CryptBlocks(result, encrypter)
	// 去除填充
	result = UnPKCS7Padding(result)
	return result, nil
}

// Encode 编码字符串（使用指定的key和iv）
func Encode(text string, key string, iv string) (string, error) {
	encoded, err := CBCEncrypt([]byte(text), []byte(key), []byte(iv))
	if err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(encoded), nil
}

// Decode 解码字符串（使用指定的key和iv）
func Decode(text string, key string, iv string) (string, error) {
	encoded, err := base64.URLEncoding.DecodeString(text)
	if err != nil {
		return "", err
	}
	txt, err := CBCDecrypt(encoded, []byte(key), []byte(iv))
	if err != nil {
		return "", err
	}
	return string(txt), nil
}
