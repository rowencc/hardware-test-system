<template>
  <div>
    <h1 class="page-title"><i class="fas fa-truck"></i> 返厂管理</h1>

    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-bottom:20px;">
      <div class="stat-card"><div class="stat-value" style="color:var(--color-primary);">{{ stats.total || 0 }}</div><div class="stat-label">全部返厂</div></div>
      <div class="stat-card"><div class="stat-value" style="color:var(--color-warning);">{{ stats.pending || 0 }}</div><div class="stat-label">在途</div></div>
      <div class="stat-card"><div class="stat-value" style="color:var(--color-success);">{{ stats.completed || 0 }}</div><div class="stat-label">已完成</div></div>
      <div class="stat-card"><div class="stat-value" style="color:var(--color-error);">{{ stats.exception || 0 }}</div><div class="stat-label">异常</div></div>
    </div>

    <div style="display:flex;gap:8px;margin-bottom:16px;flex-wrap:wrap;">
      <input v-model="search" class="form-control" placeholder="搜索..." style="width:200px;" @input="debouncedSearch" />
      <button class="btn btn-sm btn-primary" @click="showCreateModal"><i class="fas fa-plus"></i> 新建返厂记录</button>
    </div>

    <table class="data-table">
      <thead><tr><th>ID</th><th>设备</th><th>返厂原因</th><th>快递公司</th><th>快递单号</th><th>状态</th><th>寄出时间</th><th>操作</th></tr></thead>
      <tbody>
        <tr v-for="r in records" :key="r.id">
          <td>{{ r.id }}</td>
          <td><code>{{ r.board_mac }}</code></td>
          <td>{{ r.return_reason || '--' }}</td>
          <td>{{ r.courier || '--' }}</td>
          <td>
            <span v-if="r.tracking_no" style="cursor:pointer;color:var(--color-primary);" @click="queryLogistics(r.tracking_no);logisticsModalVisible=true">{{ r.tracking_no }}</span>
            <span v-else>--</span>
          </td>
          <td><span class="status-badge" :class="'status-' + (r.status === 'in_transit' ? 'in_progress' : r.status)">{{ dispStatus(r.status) }}</span></td>
          <td style="font-size:12px;">{{ formatDate(r.sent_time) }}</td>
          <td class="actions-cell">
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

    <Modal :visible="modalVisible" :title="editingId ? '编辑返厂记录' : '新建返厂记录'" icon="fas fa-truck" @close="modalVisible=false" wide>
      <div class="form-group"><label class="form-label">关联设备</label><select v-model="form.device_id" class="form-control"><option value="">-- 选择设备 --</option><option v-for="dev in availableDevices" :key="dev.id" :value="dev.id">{{ dev.board_mac }}</option></select></div>
      <div class="form-group"><label class="form-label">返厂原因</label><input v-model="form.return_reason" class="form-control" /></div>
      <div class="form-group"><label class="form-label">快递公司</label><input v-model="form.courier" class="form-control" /></div>
      <div class="form-group"><label class="form-label">快递单号</label><input v-model="form.tracking_no" class="form-control" /></div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group"><label class="form-label">状态</label><select v-model="form.status" class="form-control"><option value="in_transit">在途</option><option value="completed">完成</option><option value="exception">异常</option></select></div>
        <div class="form-group"><label class="form-label">寄出时间</label><input v-model="form.sent_time" type="date" class="form-control" /></div>
      </div>
      <div class="form-group"><label class="form-label">备注</label><textarea v-model="form.remark" class="form-control"></textarea></div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="modalVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="saveRecord">保存</button>
      </template>
    </Modal>

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
const stats = ref({ total: 0, pending: 0, completed: 0, exception: 0 })
const page = ref(1); const totalPages = ref(1)
const search = ref('')
const modalVisible = ref(false); const editingId = ref(null)
const form = ref({ device_id: '', return_reason: '', courier: '', tracking_no: '', sent_time: '', status: 'in_transit', remark: '' })
const availableDevices = ref([])
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
  try { const res = await statsAPI.returnSummary(); const d = res.data || res; stats.value = { total: d.total || 0, pending: d.in_transit || 0, completed: d.completed || 0, exception: d.exception || 0 } } catch {}
}
function dispStatus(s) { const m = { in_transit: '在途', completed: '完成', exception: '异常' }; return m[s] || s }
async function showCreateModal() {
  editingId.value = null; form.value = { device_id: '', return_reason: '', courier: '', tracking_no: '', sent_time: new Date().toISOString().slice(0,10), status: 'in_transit', remark: '' }
  try { const res = await returnAPI.availableDevices(); availableDevices.value = (res.data || res || []) } catch { availableDevices.value = [] }
  modalVisible.value = true
}
function showEditModal(r) { editingId.value = r.id; form.value = { ...r, device_id: r.device_id || '' }; availableDevices.value = []; modalVisible.value = true }
async function saveRecord() {
  try {
    if (editingId.value) { await returnAPI.update(editingId.value, form.value); uiStore.notify('返厂记录已更新', 'success') }
    else { await returnAPI.create(form.value); uiStore.notify('返厂记录已创建', 'success') }
    modalVisible.value = false; loadRecords(); loadStats()
  } catch (e) { uiStore.notify(e.response?.data?.message || '操作失败', 'error') }
}
async function confirmDelete(r) { if (!confirm(`确认删除返厂记录 #${r.id}？`)) return; try { await returnAPI.delete(r.id); uiStore.notify('删除成功', 'success'); loadRecords(); loadStats() } catch {} }
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
</style>
