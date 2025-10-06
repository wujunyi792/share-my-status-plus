import React from 'react';
import { Link } from 'react-router-dom';
import { Music, Monitor, Activity, Share2, Zap } from 'lucide-react';

export function HomePage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      {/* 导航栏 */}
      <nav className="bg-white shadow-sm">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <div className="flex-shrink-0 flex items-center">
                <Zap className="h-8 w-8 text-primary-600" />
                <span className="ml-2 text-xl font-bold text-gray-900">
                  Share My Status Plus
                </span>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              <Link
                to="/docs"
                className="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md text-sm font-medium"
              >
                文档
              </Link>
            </div>
          </div>
        </div>
      </nav>

      {/* 主要内容 */}
      <main>
        {/* Hero Section */}
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
          <div className="text-center">
            <h1 className="text-4xl md:text-6xl font-bold text-gray-900 mb-6">
              实时分享你的状态
            </h1>
            <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
              分享你的音乐播放状态、系统活动等信息，让同事和朋友了解你正在做什么。
              轻量、实时、可控的个人状态共享平台。
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Link
                to="/s/demo"
                className="bg-primary-600 text-white px-8 py-3 rounded-lg font-semibold hover:bg-primary-700 transition-colors"
              >
                查看演示
              </Link>
              <a
                href="#features"
                className="border border-gray-300 text-gray-700 px-8 py-3 rounded-lg font-semibold hover:bg-gray-50 transition-colors"
              >
                了解更多
              </a>
            </div>
          </div>
        </div>

        {/* Features Section */}
        <div id="features" className="bg-white py-20">
          <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-16">
              <h2 className="text-3xl font-bold text-gray-900 mb-4">
                核心功能
              </h2>
              <p className="text-xl text-gray-600">
                提供完整的实时状态分享解决方案
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
              {/* 音乐状态 */}
              <div className="text-center p-6 rounded-xl bg-gradient-to-br from-green-50 to-emerald-50">
                <div className="inline-flex items-center justify-center w-16 h-16 bg-green-100 rounded-full mb-4">
                  <Music className="w-8 h-8 text-green-600" />
                </div>
                <h3 className="text-xl font-semibold text-gray-900 mb-2">
                  音乐状态分享
                </h3>
                <p className="text-gray-600">
                  实时分享当前播放的音乐信息，包括歌曲名、艺术家、专辑和封面
                </p>
              </div>

              {/* 系统状态 */}
              <div className="text-center p-6 rounded-xl bg-gradient-to-br from-blue-50 to-cyan-50">
                <div className="inline-flex items-center justify-center w-16 h-16 bg-blue-100 rounded-full mb-4">
                  <Monitor className="w-8 h-8 text-blue-600" />
                </div>
                <h3 className="text-xl font-semibold text-gray-900 mb-2">
                  系统状态监控
                </h3>
                <p className="text-gray-600">
                  监控和分享系统状态，包括电池、CPU、内存使用情况
                </p>
              </div>

              {/* 活动状态 */}
              <div className="text-center p-6 rounded-xl bg-gradient-to-br from-purple-50 to-violet-50">
                <div className="inline-flex items-center justify-center w-16 h-16 bg-purple-100 rounded-full mb-4">
                  <Activity className="w-8 h-8 text-purple-600" />
                </div>
                <h3 className="text-xl font-semibold text-gray-900 mb-2">
                  活动状态展示
                </h3>
                <p className="text-gray-600">
                  显示当前正在进行的活动，如工作、学习、休息等状态
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* How it works */}
        <div className="bg-gray-50 py-20">
          <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-16">
              <h2 className="text-3xl font-bold text-gray-900 mb-4">
                工作原理
              </h2>
              <p className="text-xl text-gray-600">
                简单三步，开始分享你的状态
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
              <div className="text-center">
                <div className="inline-flex items-center justify-center w-12 h-12 bg-primary-100 rounded-full mb-4">
                  <span className="text-primary-600 font-bold text-lg">1</span>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">
                  安装客户端
                </h3>
                <p className="text-gray-600">
                  下载并安装客户端应用，配置你的分享密钥
                </p>
              </div>

              <div className="text-center">
                <div className="inline-flex items-center justify-center w-12 h-12 bg-primary-100 rounded-full mb-4">
                  <span className="text-primary-600 font-bold text-lg">2</span>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">
                  开始分享
                </h3>
                <p className="text-gray-600">
                  客户端自动收集并上报你的状态信息到服务器
                </p>
              </div>

              <div className="text-center">
                <div className="inline-flex items-center justify-center w-12 h-12 bg-primary-100 rounded-full mb-4">
                  <span className="text-primary-600 font-bold text-lg">3</span>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">
                  实时展示
                </h3>
                <p className="text-gray-600">
                  通过分享链接，其他人可以实时查看你的状态
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Privacy Section */}
        <div className="bg-white py-20">
          <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-16">
              <h2 className="text-3xl font-bold text-gray-900 mb-4">
                隐私与安全
              </h2>
              <p className="text-xl text-gray-600">
                我们重视你的隐私，提供完全可控的数据分享
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div className="space-y-4">
                <div className="flex items-start space-x-3">
                  <div className="flex-shrink-0">
                    <div className="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center">
                      <div className="w-2 h-2 bg-green-600 rounded-full"></div>
                    </div>
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900">最小化收集</h3>
                    <p className="text-gray-600">只收集必要的状态信息，不涉及敏感数据</p>
                  </div>
                </div>

                <div className="flex items-start space-x-3">
                  <div className="flex-shrink-0">
                    <div className="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center">
                      <div className="w-2 h-2 bg-green-600 rounded-full"></div>
                    </div>
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900">完全可控</h3>
                    <p className="text-gray-600">你可以随时开启或关闭任何类型的状态分享</p>
                  </div>
                </div>

                <div className="flex items-start space-x-3">
                  <div className="flex-shrink-0">
                    <div className="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center">
                      <div className="w-2 h-2 bg-green-600 rounded-full"></div>
                    </div>
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900">安全传输</h3>
                    <p className="text-gray-600">所有数据传输都经过加密，确保安全</p>
                  </div>
                </div>
              </div>

              <div className="space-y-4">
                <div className="flex items-start space-x-3">
                  <div className="flex-shrink-0">
                    <div className="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center">
                      <div className="w-2 h-2 bg-green-600 rounded-full"></div>
                    </div>
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900">可撤销分享</h3>
                    <p className="text-gray-600">随时可以撤销分享链接，立即停止状态展示</p>
                  </div>
                </div>

                <div className="flex items-start space-x-3">
                  <div className="flex-shrink-0">
                    <div className="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center">
                      <div className="w-2 h-2 bg-green-600 rounded-full"></div>
                    </div>
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900">本地处理</h3>
                    <p className="text-gray-600">敏感信息在本地处理，不会上传到服务器</p>
                  </div>
                </div>

                <div className="flex items-start space-x-3">
                  <div className="flex-shrink-0">
                    <div className="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center">
                      <div className="w-2 h-2 bg-green-600 rounded-full"></div>
                    </div>
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900">透明化</h3>
                    <p className="text-gray-600">清楚地展示当前生效的配置和授权状态</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="bg-gray-900 text-white py-12">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center">
            <div className="flex items-center justify-center mb-4">
              <Zap className="h-8 w-8 text-primary-400" />
              <span className="ml-2 text-xl font-bold">Share My Status Plus</span>
            </div>
            <p className="text-gray-400 mb-4">
              让分享更简单，让隐私更安全
            </p>
            <p className="text-gray-500 text-sm">
              © 2024 Share My Status Plus. All rights reserved.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}
