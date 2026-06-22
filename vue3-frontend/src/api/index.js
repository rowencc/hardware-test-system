import axios from 'axios'
import { useAuthStore } from '@/stores/auth'

const api = axios.create({
  baseURL: '/api',
  timeout: 30000,
  headers: { 'Content-Type': 'application/json' }
})

api.interceptors.request.use(config => {
  config.withCredentials = true
  return config
})

api.interceptors.response.use(
  res => res.data,
  err => {
    if (err.response?.status === 401) {
      const authStore = useAuthStore()
      authStore.clearUser()
    }
    return Promise.reject(err)
  }
)

// ===== Auth =====
export const authAPI = {
  login: (username, password) => api.post('/auth/login', { username, password }),
  logout: () => api.post('/auth/logout'),
  me: () => api.get('/auth/me'),
}

// ===== Batches =====
export const batchAPI = {
  generateNo: () => api.get('/batches/generate-no'),
  list: (params) => api.get('/batches', { params }),
  get: (id) => api.get(`/batches/${id}`),
  create: (data) => api.post('/batches', data),
  update: (id, data) => api.put(`/batches/${id}`, data),
  delete: (id) => api.delete(`/batches/${id}`),
  updateStatus: (id, data) => api.put(`/batches/${id}/status`, data),
  getDevices: (id, params) => api.get(`/batches/${id}/devices`, { params }),
  initResults: (id, data) => api.post(`/batches/${id}/init-results`, data),
  exportExcel: (id) => `/api/batches/${id}/export/excel`,
}

// ===== Devices =====
export const deviceAPI = {
  list: (params) => api.get('/devices', { params }),
  get: (id) => api.get(`/devices/${id}`),
  create: (data) => api.post('/devices', data),
  batchCreate: (data) => api.post('/devices/batch', data),
  update: (id, data) => api.put(`/devices/${id}`, data),
  delete: (id) => api.delete(`/devices/${id}`),
  getResults: (id) => api.get(`/devices/${id}/results`),
  updateResults: (id, data) => api.put(`/devices/${id}/results`, data),
  updateFault: (id, data) => api.put(`/devices/${id}/fault`, data),
  batchUpdate: (data) => api.put('/devices/batch', data),
  batchDelete: (data) => api.delete('/devices/batch', { data }),
  batchUpdateResults: (data) => api.put('/devices/batch/results', data),
}

// ===== Standards =====
export const standardAPI = {
  list: () => api.get('/standards'),
  get: (id) => api.get(`/standards/${id}`),
  create: (data) => api.post('/standards', data),
  update: (id, data) => api.put(`/standards/${id}`, data),
  delete: (id) => api.delete(`/standards/${id}`),
}

// ===== Users =====
export const userAPI = {
  list: () => api.get('/users'),
  create: (data) => api.post('/users', data),
  update: (id, data) => api.put(`/users/${id}`, data),
  delete: (id) => api.delete(`/users/${id}`),
  updatePassword: (id, data) => api.put(`/users/${id}/password`, data),
}

// ===== Statistics =====
export const statsAPI = {
  overview: () => api.get('/statistics/overview'),
  daily: (params) => api.get('/statistics/daily', { params }),
  operators: () => api.get('/statistics/operators'),
  returnSummary: () => api.get('/statistics/return-summary'),
}

// ===== Faults =====
export const faultAPI = {
  list: (params) => api.get('/faults', { params }),
}

// ===== Return Records =====
export const returnAPI = {
  list: (params) => api.get('/return-records', { params }),
  get: (id) => api.get(`/return-records/${id}`),
  create: (data) => api.post('/return-records', data),
  update: (id, data) => api.put(`/return-records/${id}`, data),
  delete: (id) => api.delete(`/return-records/${id}`),
  availableDevices: (excludeId) => api.get('/return-records/available-devices', { params: { exclude_record_id: excludeId } }),
}

// ===== Config =====
export const configAPI = {
  get: () => api.get('/config'),
  update: (data) => api.put('/config', data),
}

// ===== Logistics =====
export const logisticsAPI = {
  query: (trackingNo) => api.get('/logistics/query', { params: { tracking_no: trackingNo } }),
}

// ===== Export =====
export const exportAPI = {
  excel: (params) => api.get('/export/excel', { params }),
  markdown: (params) => api.get('/export/markdown', { params }),
  template: () => `/api/template/download`,
}

// ===== Suggestions =====
export const suggestAPI = {
  operators: () => api.get('/suggest/operators'),
}

export default api
