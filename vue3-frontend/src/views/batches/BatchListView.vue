<template>
  <div>
    <h1 class="page-title"><i class="fas fa-layer-group"></i> 批次管理</h1>

    <div style="display:flex;gap:10px;margin-bottom:16px;flex-wrap:wrap;align-items:center;">
      <input v-model="search" class="form-control" placeholder="搜索批次号/名称..." style="width:220px;" @input="debouncedSearch" />
      <select v-model="filterStatus" class="form-control" style="width:140px;" @change="loadBatches(1)">
        <option value="">全部状态</option>
        <option value="planned">计划中</option>
        <option value="in_progress">进行中</option>
        <option value="paused">暂停</option>
        <option value="completed">已完成</option>
        <option value="cancelled">已取消</option>
      </select>
      <button class="btn btn-primary" @click="showCreateModal"><i class="fas fa-plus"></i> 新建批次</button>
    </div>

    <table class="data-table">
      <thead><tr>
        <th>批次号</th><th>名称</th><th>状态</th><th>设备数</th><th>测试标准</th><th>截止日期</th><th>操作</th>
      </tr></thead>
      <tbody>
        <tr v-for="b in batches" :key="b.id">
          <td><code>{{ b.batch_no }}</code></td>
          <td><a href="#" @click.prevent="goDetail(b)" style="color:var(--color-primary);font-weight:600;text-decoration:none;">{{ b.name || b.batch_no }}</a></td>
          <td><span class="status-badge" :class="'status-'+b.status">{{ dispStatus(b.status) }}</span></td>
          <td style="text-align:center;font-family:var(--font-mono);">{{ b.device_count || 0 }}</td>
          <td>{{ b.standard_name || '--' }}</td>
          <td :style="isOverdue(b) ? 'color:var(--color-error);font-weight:600' : ''" style="font-size:12px;">{{ b.deadline || '--' }}{{ isOverdue(b) ? ' (超期)' : '' }}</td>
          <td class="actions-cell">
            <button class="btn btn-sm btn-primary" @click="goDetail(b)"><i class="fas fa-eye"></i></button>
            <button class="btn btn-sm btn-warning" @click="showEditModal(b)"><i class="fas fa-edit"></i></button>
            <button class="btn btn-sm btn-success" @click="cycleStatus(b)"><i class="fas fa-sync-alt"></i></button>
            <button class="btn btn-sm btn-error" @click="confirmDelete(b)"><i class="fas fa-trash"></i></button>
          </td>
        </tr>
        <tr v-if="!batches.length"><td colspan="7" class="empty-table"><i class="fas fa-layer-group"></i><p>暂无批次</p></td></tr>
      </tbody>
    </table>

    <div class="pagination" v-if="totalPages > 1">
      <button class="btn btn-sm btn-secondary" :disabled="page<=1" @click="loadBatches(page-1)">上一页</button>
      <span style="font-size:12px;color:var(--color-text-3);">第 {{ page }} / {{ totalPages }} 页</span>
      <button class="btn btn-sm btn-secondary" :disabled="page>=totalPages" @click="loadBatches(page+1)">下一页</button>
    </div>

    <Modal :visible="modalVisible" :title="editingId ? '编辑批次' : '新建批次'" icon="fas fa-layer-group" @close="modalVisible=false">
      <div class="form-group">
        <label class="form-label">批次号</label>
        <input v-model="form.batch_no" class="form-control" readonly :style="editingId ? '' : 'background:var(--color-primary-dim);cursor:not-allowed;font-family:var(--font-mono);'" />
        <div v-if="!editingId" style="font-size:11px;color:var(--color-text-3);margin-top:4px;">系统自动生成，可在系统设置中配置前缀</div>
      </div>
      <div class="form-group"><label class="form-label">名称</label><input v-model="form.name" class="form-control" /></div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group"><label class="form-label">测试标准</label><select v-model="form.standard_id" class="form-control"><option value="">-- 选择标准 --</option><option v-for="s in standards" :key="s.id" :value="s.id">{{ s.name }}</option></select></div>
        <div class="form-group"><label class="form-label">状态</label><select v-model="form.status" class="form-control"><option value="planned">计划中</option><option value="in_progress">进行中</option><option value="paused">暂停</option><option value="completed">已完成</option><option value="cancelled">已取消</option></select></div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group"><label class="form-label">预计开始</label><input v-model="form.start_date" type="date" class="form-control" /></div>
        <div class="form-group"><label class="form-label">截止日期</label><input v-model="form.deadline" type="date" class="form-control" /></div>
      </div>
      <div class="form-group"><label class="form-label">备注</label><textarea v-model="form.remark" class="form-control"></textarea></div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="modalVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="saveBatch">保存</button>
      </template>
    </Modal>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { batchAPI, standardAPI, configAPI } from '@/api'
import { useUiStore } from '@/stores/ui'
import { debounce, formatDate } from '@/utils'
import Modal from '@/components/common/Modal.vue'

const router = useRouter()
const uiStore = useUiStore()
const batches = ref([])
const page = ref(1); const totalPages = ref(1)
const search = ref(''); const filterStatus = ref('')
const modalVisible = ref(false); const editingId = ref(null)
const form = ref({ batch_no: '', name: '', standard_id: '', status: 'planned', start_date: '', deadline: '', remark: '' })
const standards = ref([])

const debouncedSearch = debounce(() => loadBatches(1), 300)

onMounted(() => { loadBatches(); loadStandards() })

async function loadBatches(p = 1) {
  page.value = p
  try {
    const params = { page: p, per_page: 20 }
    if (search.value) params.search = search.value
    if (filterStatus.value) params.status = filterStatus.value
    const res = await batchAPI.list(params)
    const d = res.data || res; batches.value = d.items || []; totalPages.value = d.total_pages || 1
  } catch { uiStore.notify('加载批次失败', 'error') }
}
async function loadStandards() {
  try { const res = await standardAPI.list(); standards.value = res.data || res || [] } catch {}
}
function dispStatus(s) {
  const m = { planned: '计划中', in_progress: '进行中', paused: '暂停', completed: '已完成', cancelled: '已取消' }; return m[s]||s
}
function isOverdue(b) {
  if (!b.deadline || b.status === 'completed' || b.status === 'cancelled') return false
  const dl = new Date(b.deadline); const now = new Date(); return !isNaN(dl) && dl < now
}
function goDetail(b) { router.push('/batches/' + b.id) }
async function showCreateModal() {
  editingId.value = null
  const batchNo = await generateBatchNo()
  form.value = { batch_no: batchNo, name: '', standard_id: '', status: 'planned', start_date: new Date().toISOString().slice(0,10), deadline: '', remark: '' }
  modalVisible.value = true
}
function showEditModal(b) {
  editingId.value = b.id
  const matchedStd = standards.value.find(s => s.name === b.standard_name)
  form.value = { ...b, name: b.name || '', standard_id: matchedStd?.id || '', start_date: b.start_date ? b.start_date.slice(0, 10) : '', deadline: b.deadline||'', remark: b.remark||'' }
  modalVisible.value = true
}
async function generateBatchNo() {
  const dateStr = new Date().toISOString().slice(0,10).replace(/-/g, '')
  let prefix = 'BAT'
  try {
    const res = await configAPI.get()
    const d = res.data || res
    if (d && d.batch_no_prefix) prefix = d.batch_no_prefix
  } catch {}
  try {
    const res = await batchAPI.list({ per_page: 200 })
    const items = (res.data || res || {}).items || []
    const todayPrefix = `${prefix}-${dateStr}`
    const todayCount = items.filter(b => (b.batch_no || '').startsWith(todayPrefix)).length
    const seq = String(todayCount + 1).padStart(3, '0')
    return `${todayPrefix}-${seq}`
  } catch {
    return `${prefix}-${dateStr}-001`
  }
}
async function saveBatch() {
  try {
    if (editingId.value) { await batchAPI.update(editingId.value, form.value); uiStore.notify('批次已更新','success') }
    else { await batchAPI.create(form.value); uiStore.notify('批次已创建','success') }
    modalVisible.value = false; loadBatches()
  } catch (e) { uiStore.notify(e.response?.data?.message||'操作失败','error') }
}
async function cycleStatus(b) {
  const next = { planned: 'in_progress', in_progress: 'completed', paused: 'in_progress' }
  const ns = next[b.status]; if (!ns) return
  try { await batchAPI.updateStatus(b.id, { status: ns }); uiStore.notify('状态已切换','success'); loadBatches() } catch {}
}
async function confirmDelete(b) {
  if (!confirm(`确认删除批次 ${b.batch_no}？`)) return
  try { await batchAPI.delete(b.id); uiStore.notify('批次已删除','success'); loadBatches() } catch {}
}
</script>

<style scoped>
.data-table { border-radius: var(--radius-md); overflow: hidden; }
.btn { transition: all 0.2s; }
.btn:hover { transform: translateY(-1px); }
.form-control { transition: all 0.25s ease; }
.form-control:focus { border-color: var(--color-primary); box-shadow: 0 0 0 2px var(--color-primary-dim), 0 0 12px rgba(var(--color-primary-rgb),0.15); }
</style>
