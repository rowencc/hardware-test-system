<template>
  <div>
    <h1 class="page-title"><i class="fas fa-truck"></i> 返厂管理</h1>

    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-bottom:20px;">
      <div class="stat-card"><div class="stat-value" style="color:var(--color-primary);">{{ stats.total || 0 }}</div><div class="stat-label">全部返厂</div></div>
      <div class="stat-card"><div class="stat-value" style="color:var(--color-success);">{{ stats.completed || 0 }}</div><div class="stat-label">已完成</div></div>
      <div class="stat-card"><div class="stat-value" style="color:var(--color-info);">{{ stats.avg_days || 0 }}天</div><div class="stat-label">平均返厂天数</div></div>
    </div>

    <div style="display:flex;gap:8px;margin-bottom:16px;flex-wrap:wrap;">
      <input v-model="search" class="form-control" placeholder="搜索单号/快递公司..." style="width:240px;" @input="debouncedSearch" />
      <button class="btn btn-sm btn-primary" @click="showCreateModal"><i class="fas fa-plus"></i> 新建返厂记录</button>
    </div>

    <table class="data-table">
      <thead><tr><th>ID</th><th>返厂单编号</th><th>快递公司</th><th>快递单号</th><th>状态</th><th>设备数</th><th>创建时间</th><th>操作</th></tr></thead>
      <tbody>
        <tr v-for="r in records" :key="r.id">
          <td>{{ r.id }}</td>
          <td><code style="font-size:12px;">{{ r.return_code || '--' }}</code></td>
          <td>{{ r.courier || '--' }}</td>
          <td>
            <span v-if="r.tracking_no" style="cursor:pointer;color:var(--color-primary);" @click="queryLogistics(r.tracking_no);logisticsModalVisible=true">{{ r.tracking_no }}</span>
            <span v-else>--</span>
          </td>
          <td><span class="status-badge" :class="statusClass(r.status)">{{ r.status }}</span></td>
          <td>{{ r.device_count }}</td>
          <td style="font-size:12px;">{{ formatDate(r.created_at) }}</td>
          <td class="actions-cell">
            <button class="btn btn-sm btn-info" @click="showDetailModal(r)"><i class="fas fa-eye"></i></button>
            <button class="btn btn-sm btn-warning" @click="showEditModal(r)"><i class="fas fa-edit"></i></button>
            <button class="btn btn-sm btn-error" @click="confirmDelete(r)"><i class="fas fa-trash"></i></button>
          </td>
        </tr>
        <tr v-if="!records.length"><td colspan="8" class="empty-table"><i class="fas fa-truck"></i><p>暂无返厂记录</p></td></tr>
      </tbody>
    </table>

    <div class="pagination" v-if="totalPages > 1">
      <button class="btn btn-sm btn-secondary" :disabled="page<=1" @click="loadRecords(page-1)">上一页</button>
      <span style="font-size:12px;color:var(--color-text-3);">第 {{ page }} / {{ totalPages }} 页</span>
      <button class="btn btn-sm btn-secondary" :disabled="page>=totalPages" @click="loadRecords(page+1)">下一页</button>
    </div>

    <!-- 新建/编辑弹窗 -->
    <Modal :visible="modalVisible" :title="editingId ? '编辑返厂记录' : '新建返厂记录'" icon="fas fa-truck" @close="modalVisible=false" wide>
      <div class="form-group"><label class="form-label">关联设备（可多选，仅显示"待返厂"设备）</label>
        <select v-model="form.device_ids" multiple class="form-control" style="min-height:120px;">
          <option v-for="dev in availableDevices" :key="dev.id" :value="dev.id">{{ dev.device_code || dev.board_mac }} — {{ dev.board_mac }}</option>
        </select>
        <div style="font-size:11px;color:var(--color-text-3);margin-top:4px;">已选 {{ form.device_ids.length }} 个设备（按住 Ctrl/Cmd 多选）</div>
      </div>
      <div class="form-group"><label class="form-label">返厂单编号</label>
        <input v-model="form.return_code" class="form-control" placeholder="留空自动生成" />
      </div>
      <div class="form-group"><label class="form-label">快递公司</label><input v-model="form.courier" class="form-control" /></div>
      <div class="form-group"><label class="form-label">快递单号 <span style="color:var(--color-error);">*</span></label><input v-model="form.tracking_no" class="form-control" placeholder="必填" /></div>
      <div class="form-group"><label class="form-label">状态</label>
        <select v-model="form.status" class="form-control">
          <option value="进行中">进行中</option>
          <option value="完成">完成</option>
          <option value="取消">取消</option>
        </select>
      </div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="modalVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="saveRecord">保存</button>
      </template>
    </Modal>

    <!-- 详情弹窗 -->
    <Modal :visible="detailVisible" title="返厂记录详情" icon="fas fa-info-circle" @close="detailVisible=false" wide>
      <div v-if="detail" style="display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:16px;">
        <div><label class="form-label">返厂单编号</label><div>{{ detail.return_code || '--' }}</div></div>
        <div><label class="form-label">快递单号</label><div>{{ detail.tracking_no }}</div></div>
        <div><label class="form-label">快递公司</label><div>{{ detail.courier || '--' }}</div></div>
        <div><label class="form-label">状态</label><div><span class="status-badge" :class="statusClass(detail.status)">{{ detail.status }}</span></div></div>
        <div><label class="form-label">关联设备数</label><div>{{ detail.device_count }}</div></div>
        <div><label class="form-label">创建时间</label><div style="font-size:12px;">{{ formatDate(detail.created_at) }}</div></div>
      </div>
      <div v-if="detail && detail.devices && detail.devices.length">
        <label class="form-label">关联设备列表</label>
        <table class="data-table">
          <thead><tr><th>设备编号</th><th>MAC地址</th><th>处置状态</th></tr></thead>
          <tbody>
            <tr v-for="d in detail.devices" :key="d.id">
              <td><code>{{ d.device_code || '--' }}</code></td>
              <td>{{ d.board_mac }}</td>
              <td><span class="status-badge" :class="dispStatusClass(d.fault_disposition)">{{ d.fault_disposition }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </Modal>

    <!-- 物流弹窗 -->
    <Modal :visible="logisticsModalVisible" title="物流查询" icon="fas fa-truck" @close="logisticsModalVisible=false" wide>
      <div style="display:flex;gap:8px;margin-bottom:14px;">
        <input v-model="trackingNoQuery" class="form-control" placeholder="输入快递单号" style="flex:1;" />
        <button class="btn btn-primary btn-sm" @click="queryLogistics(trackingNoQuery)">查询</button>
      </div>
      <div v-if="logisticsLoading" style="text-align:center;padding:20px;color:var(--color-text-3);">查询中...</div>
      <div v-else-if="logisticsResult" style="max-height:300px;overflow-y:auto;">
        <div v-if="logisticsResult.state" style="font-size:13px;margin-bottom:10px;">
          <strong>{{ logisticsResult.nu || trackingNoQuery }}</strong>
          <span class="status-badge" style="margin-left:10px;background:rgba(0,240,255,0.1);color:var(--color-primary);border:1px solid rgba(var(--color-primary-rgb),0.2);">{{ logisticsResult.state }}</span>
        </div>
        <div v-if="logisticsResult.data && logisticsResult.data.length" style="border-left:2px solid var(--color-primary);padding-left:14px;">
          <div v-for="item in logisticsResult.data" :key="item.time" style="margin-bottom:12px;position:relative;">
            <div style="position:absolute;left:-22px;top:6px;width:10px;height:10px;border-radius:50%;background:var(--color-primary);box-shadow:0 0 8px var(--color-primary);"></div>
            <div style="font-size:13px;">{{ item.context }}</div>
            <div style="font-size:11px;color:var(--color-text-3);margin-top:2px;">{{ item.time }}</div>
          </div>
        </div>
        <div v-else style="text-align:center;padding:20px;color:var(--color-text-3);">未查到物流信息</div>
      </div>
    </Modal>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { returnAPI, statsAPI, logisticsAPI } from '@/api'
import { useUiStore } from '@/stores/ui'
import { formatDate, debounce } from '@/utils'
import Modal from '@/components/common/Modal.vue'

const uiStore = useUiStore()
const records = ref([])
const stats = ref({ total: 0, completed: 0, avg_days: 0 })
const page = ref(1); const totalPages = ref(1)
const search = ref('')
const modalVisible = ref(false); const editingId = ref(null)
const form = ref({ device_ids: [], return_code: '', courier: '', tracking_no: '', status: '进行中' })
const availableDevices = ref([])
const detailVisible = ref(false); const detail = ref(null)
const logisticsModalVisible = ref(false); const trackingNoQuery = ref(''); const logisticsLoading = ref(false); const logisticsResult = ref(null)

const debouncedSearch = debounce(() => loadRecords(1), 300)

onMounted(() => { loadRecords(); loadStats() })

async function loadRecords(p = 1) {
  page.value = p
  try {
    const params = { page: p, per_page: 20 }
    if (search.value) params.search = search.value
    const res = await returnAPI.list(params); const d = res.data || res; records.value = d.items || []; totalPages.value = d.total_pages || 1
  } catch { uiStore.notify('加载返厂记录失败', 'error') }
}
async function loadStats() {
  try {
    const res = await statsAPI.returnSummary(); const d = res.data || res
    stats.value = { total: d.total || 0, completed: d.completed || 0, avg_days: d.avg_days || 0 }
  } catch {}
}
function statusClass(s) {
  if (s === '完成') return 'status-completed'
  if (s === '取消') return 'status-cancelled'
  return 'status-in_progress'
}
function dispStatusClass(s) {
  if (s === '已返厂') return 'status-returned-done'
  if (s === '返厂中') return 'status-returning'
  return ''
}
async function showCreateModal() {
  editingId.value = null
  form.value = { device_ids: [], return_code: '', courier: '', tracking_no: '', status: '进行中' }
  try { const res = await returnAPI.availableDevices(); availableDevices.value = (res.data || res || []) } catch { availableDevices.value = [] }
  modalVisible.value = true
}
async function showEditModal(r) {
  editingId.value = r.id
  try {
    const res = await returnAPI.get(r.id)
    const d = res.data || res
    form.value = {
      device_ids: (d.devices || []).map(dev => dev.id),
      return_code: d.return_code || '',
      courier: d.courier || '',
      tracking_no: d.tracking_no || '',
      status: d.status || '进行中',
    }
  } catch {
    form.value = { device_ids: [], return_code: r.return_code || '', courier: r.courier || '', tracking_no: r.tracking_no || '', status: r.status || '进行中' }
  }
  try { const res = await returnAPI.availableDevices(r.id); availableDevices.value = (res.data || res || []) } catch { availableDevices.value = [] }
  modalVisible.value = true
}
async function saveRecord() {
  if (!form.value.tracking_no) { uiStore.notify('快递单号不能为空', 'error'); return }
  if (!form.value.device_ids.length) { uiStore.notify('请至少选择一个设备', 'error'); return }
  try {
    if (editingId.value) {
      await returnAPI.update(editingId.value, form.value)
      uiStore.notify('返厂记录已更新', 'success')
    } else {
      await returnAPI.create(form.value)
      uiStore.notify('返厂记录已创建', 'success')
    }
    modalVisible.value = false; loadRecords(); loadStats()
  } catch (e) { uiStore.notify(e.response?.data?.message || '操作失败', 'error') }
}
async function showDetailModal(r) {
  try {
    const res = await returnAPI.get(r.id)
    detail.value = res.data || res
    detailVisible.value = true
  } catch { uiStore.notify('获取详情失败', 'error') }
}
async function confirmDelete(r) { if (!confirm(`确认删除返厂记录 #${r.id}？关联设备将恢复为"待返厂"`)) return; try { await returnAPI.delete(r.id); uiStore.notify('删除成功', 'success'); loadRecords(); loadStats() } catch {} }
async function queryLogistics(tn) {
  if (!tn) return; logisticsLoading.value = true; logisticsResult.value = null; trackingNoQuery.value = tn
  try { const res = await logisticsAPI.query(tn); logisticsResult.value = (res.data || res) || null } catch { logisticsResult.value = null }
  logisticsLoading.value = false
}
</script>

<style scoped>
.stat-card { text-align: left; }
.stat-card .stat-value { font-size: 26px; font-weight: 800; font-family: var(--font-mono); padding-left: 12px; }
.stat-card .stat-label { font-size: 11px; color: var(--color-text-3); padding-left: 12px; text-transform: uppercase; letter-spacing: 1px; font-weight: 600; }
.data-table { border-radius: var(--radius-md); overflow: hidden; }
.btn { transition: all 0.2s; }
.btn:hover { transform: translateY(-1px); }
.form-control { transition: all 0.25s ease; }
.form-control:focus { border-color: var(--color-primary); box-shadow: 0 0 0 2px var(--color-primary-dim), 0 0 12px rgba(var(--color-primary-rgb),0.15); }
.status-badge.status-completed { background: rgba(34, 197, 94, 0.1); color: var(--color-success); border: 1px solid rgba(34, 197, 94, 0.3); }
.status-badge.status-cancelled { background: rgba(156, 163, 175, 0.1); color: var(--color-text-3); border: 1px solid rgba(156, 163, 175, 0.3); }
.status-badge.status-in_progress { background: rgba(59, 130, 246, 0.1); color: #3b82f6; border: 1px solid rgba(59, 130, 246, 0.3); }
.status-badge.status-returning { background: rgba(249,115,22,0.1); color: #fb923c; border: 1px solid rgba(249,115,22,0.3); }
.status-badge.status-returned-done { background: rgba(156,163,175,0.1); color: #d1d5db; border: 1px solid rgba(156,163,175,0.3); }
.empty-table { text-align: center; padding: 40px 16px; color: var(--color-text-3); }
.empty-table i { font-size: 28px; display: block; margin-bottom: 8px; opacity: 0.5; }
</style>
