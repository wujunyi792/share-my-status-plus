import type { StorageConfig } from '../types';

const STORAGE_KEY = 'shareStatusConfig';

/**
 * 保存配置到 Record
 */
export async function saveConfig(config: StorageConfig, docMiniApp: any): Promise<void> {
  try {
    if (!docMiniApp) {
      throw new Error('DocMiniApp not available');
    }
    
    // 使用 Record.setRecord 保存数据
    // API 格式：Record.setRecord([{ type: 'insert'|'replace'|'remove', data: { path: [], value: ... } }])
    if (docMiniApp.Record && typeof docMiniApp.Record.setRecord === 'function') {
      await docMiniApp.Record.setRecord([
        {
          type: 'replace',
          data: {
            path: [STORAGE_KEY],
            value: config
          }
        }
      ]);
      return;
    }
    
    // 兼容旧版本 API
    if (typeof docMiniApp.setRecord === 'function') {
      await docMiniApp.setRecord([
        {
          type: 'replace',
          data: {
            path: [STORAGE_KEY],
            value: config
          }
        }
      ]);
      return;
    }
    
    throw new Error('Record.setRecord API not available');
  } catch (error) {
    console.error('Failed to save config:', error);
    throw error;
  }
}

/**
 * 从 Record 读取配置
 */
export async function loadConfig(docMiniApp: any): Promise<StorageConfig | null> {
  try {
    if (!docMiniApp) {
      console.warn('DocMiniApp not available, returning null');
      return null;
    }
    
    let record: any = null;
    
    // 使用 Record.getRecord 读取整个 Record 对象
    // 根据错误信息，getRecord 不接受数组参数，应该不传参数或传递 undefined
    if (docMiniApp.Record && typeof docMiniApp.Record.getRecord === 'function') {
      // 不传参数获取整个 Record
      record = await docMiniApp.Record.getRecord();
    }
    // 兼容旧版本 API
    else if (typeof docMiniApp.getRecord === 'function') {
      record = await docMiniApp.getRecord();
    }
    
    if (!record) {
      console.log('No record found');
      return null;
    }
    
    console.log('Record data:', record);
    
    // 如果返回的是对象，从路径中提取值
    if (typeof record === 'object' && !Array.isArray(record)) {
      // 根据保存时的路径 [STORAGE_KEY]，尝试获取该路径的值
      if (STORAGE_KEY in record) {
        const config = record[STORAGE_KEY];
        // 验证配置格式
        if (config && typeof config === 'object' && 'apiBaseUrl' in config && 'sharingKey' in config) {
          return config as StorageConfig;
    } 
      }
      
      // 如果没有找到 key，检查是否整个对象就是配置（兼容旧格式）
      if (record.apiBaseUrl && record.sharingKey) {
        return record as StorageConfig;
      }
    }
    
    // 如果返回的是字符串，需要解析
    if (typeof record === 'string') {
      const parsed = JSON.parse(record);
      if (parsed && typeof parsed === 'object') {
        if (STORAGE_KEY in parsed) {
          const config = parsed[STORAGE_KEY];
          if (config && typeof config === 'object' && 'apiBaseUrl' in config && 'sharingKey' in config) {
            return config as StorageConfig;
    }
        }
        if (parsed.apiBaseUrl && parsed.sharingKey) {
          return parsed as StorageConfig;
        }
      }
    }
    
    console.log('Config not found in record');
    return null;
  } catch (error) {
    console.error('Failed to load config:', error);
    return null;
  }
}

/**
 * 清除配置
 */
export async function clearConfig(docMiniApp: any): Promise<void> {
  try {
    if (!docMiniApp) {
      throw new Error('DocMiniApp not available');
    }
    
    // 使用 Record.setRecord 的 remove 类型来清除数据
    if (docMiniApp.Record && typeof docMiniApp.Record.setRecord === 'function') {
      await docMiniApp.Record.setRecord([
        {
          type: 'remove',
          data: {
            path: [STORAGE_KEY]
          }
        }
      ]);
      return;
    }
    
    // 兼容旧版本 API
    if (typeof docMiniApp.setRecord === 'function') {
      await docMiniApp.setRecord([
        {
          type: 'remove',
          data: {
            path: [STORAGE_KEY]
          }
        }
      ]);
      return;
    }
    
    throw new Error('Record.setRecord API not available');
  } catch (error) {
    console.error('Failed to clear config:', error);
    throw error;
  }
}

