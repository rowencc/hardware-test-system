export function formatDateTime(dt) {
  if (!dt) return '--'
  const d = new Date(dt)
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}

export function formatDate(dt) {
  if (!dt) return '--'
  const d = new Date(dt)
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`
}

export function escapeHtml(str) {
  if (!str) return ''
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

export function debounce(fn, delay = 300) {
  let timer = null
  return function (...args) {
    clearTimeout(timer)
    timer = setTimeout(() => fn.apply(this, args), delay)
  }
}

export function getStatusText(status) {
  const map = { planned:'计划中', in_progress:'进行中', paused:'暂停', completed:'完成', cancelled:'取消' }
  return map[status] || status
}

export function getDeviceStatusText(status) {
  const map = { normal:'正常', fault:'故障', pending:'待测' }
  return map[status] || status
}

export function getRating(yieldRate) {
  if (yieldRate >= 98) return 'S'
  if (yieldRate >= 90) return 'A'
  if (yieldRate >= 80) return 'B'
  if (yieldRate >= 60) return 'C'
  return 'D'
}

export const STATUS_OPTIONS = [
  { value: 'planned', label: '计划中' },
  { value: 'in_progress', label: '进行中' },
  { value: 'paused', label: '暂停' },
  { value: 'completed', label: '完成' },
  { value: 'cancelled', label: '取消' },
]

export const DEVICE_STATUS_OPTIONS = [
  { value: 'normal', label: '正常' },
  { value: 'fault', label: '故障' },
  { value: 'pending', label: '待测' },
]

export const DISPOSITION_OPTIONS = [
  { value: 'returned', label: '已返厂' },
  { value: 'stored', label: '已入库' },
  { value: 'pending', label: '待处理' },
]
