<template>
  <div>
    <h1 class="page-title"><i class="fas fa-server"></i> 设备管理</h1>

    <div style="display:flex;gap:10px;margin-bottom:16px;flex-wrap:wrap;align-items:center;">
      <input v-model="search" class="form-control" placeholder="搜索MAC/IP..." style="width:200px;" @input="debouncedSearch" />
      <select v-model="filterStatus" class="form-control" style="width:120px;" @change="loadDevices(1)"><option value="">全部状态</option><option value="正常">正常</option><option value="故障">故障</option><option value="待处理">待处理</option></select>
      <select v-model="filterBatch" class="form-control" style="width:160px;" @change="loadDevices(1)"><option value="">全部批次</option><option v-for="b in batches" :key="b.id" :value="b.id">{{ b.batch_no }}</option></select>
    </div>

    <div style="display:flex;gap:6px;margin-bottom:14px;flex-wrap:wrap;">
      <button class="btn btn-sm btn-primary" @click="showCreateDevice"><i class="fas fa-plus"></i> 添加设备</button>
      <button class="btn btn-sm btn-secondary" :disabled="!selectedIds.length" @click="batchStatusModalVisible=true">批量改状态</button>
      <button class="btn btn-sm btn-secondary" :disabled="!selectedIds.length" @click="batchDisposalModalVisible=true">批量改处置</button>
      <button class="btn btn-sm btn-error" :disabled="!selectedIds.length" @click="confirmBatchDelete">批量删除</button>
    </div>

    <table class="data-table">
      <thead><tr>
        <th class="col-check"><input type="checkbox" @change="toggleAll($event)" :checked="allSelected"></th>
        <th>板卡MAC</th><th>无线MAC</th><th>IP地址</th><th>所属批次</th><th>状态</th><th>处置方式</th><th>操作员</th><th>操作</th>
      </tr></thead>
      <tbody>
        <tr v-for="d in devices" :key="d.id">
          <td class="col-check"><input type="checkbox" :value="d.id" v-model="selectedIds"></td>
          <td><code>{{ d.board_mac }}</code></td>
          <td><code>{{ d.wireless_mac || '--' }}</code></td>
          <td>{{ d.ip_address || '--' }}</td>
          <td>{{ d.batch_no || '--' }}</td>
          <td><span class="status-badge" :class="statusClass(d.status)">{{ dispStatus(d.status) }}</span></td>
          <td>{{ d.disposal_type || '--' }}</td>
          <td>{{ d.operator || d.tester || '--' }}</td>
          <td class="actions-cell">
            <button class="btn btn-xs btn-warning" @click="showEditModal(d)"><i class="fas fa-edit"></i></button>
            <button class="btn btn-xs btn-error" @click="confirmDelete(d)"><i class="fas fa-trash"></i></button>
          </td>
        </tr>
        <tr v-if="!devices.length"><td colspan="9" class="empty-table"><i class="fas fa-server"></i><p>暂无设备</p></td></tr>
      </tbody>
    </table>

    <div class="pagination" v-if="totalPages > 1">
      <button class="btn btn-sm btn-secondary" :disabled="page<=1" @click="loadDevices(page-1)">上一页</button>
      <span style="font-size:12px;color:var(--color-text-3);">第 {{ page }} / {{ totalPages }} 页</span>
      <button class="btn btn-sm btn-secondary" :disabled="page>=totalPages" @click="loadDevices(page+1)">下一页</button>
    </div>

    <!-- Edit Device Modal -->
    <Modal :visible="editVisible" title="编辑设备" icon="fas fa-server" @close="editVisible=false">
      <div class="form-group"><label class="form-label">板卡MAC</label><input v-model="editForm.board_mac" class="form-control" /></div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group"><label class="form-label">无线MAC</label><input v-model="editForm.wireless_mac" class="form-control" placeholder="如: 00:1A:2B:3C:4D:5F" /></div>
        <div class="form-group"><label class="form-label">IP地址</label><input v-model="editForm.ip_address" class="form-control" placeholder="如: 192.168.1.100" /></div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group">
          <label class="form-label">状态</label>
          <select v-model="editForm.status" class="form-control"><option value="normal">正常</option><option value="fault">故障</option></select>
        </div>
        <div class="form-group"><label class="form-label">测试时间</label><input v-model="editForm.test_date" type="datetime-local" class="form-control" /></div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group"><label class="form-label">操作员</label><input v-model="editForm.operator" class="form-control" placeholder="操作员姓名" /></div>
      </div>
      <div class="form-group"><label class="form-label">故障原因</label><textarea v-model="editForm.fault_reason" class="form-control" placeholder="故障原因或现象描述"></textarea></div>
      <div class="form-group"><label class="form-label">备注</label><textarea v-model="editForm.notes" class="form-control"></textarea></div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="editVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="saveEdit">保存</button>
      </template>
    </Modal>

    <!-- Create Device Modal -->
    <Modal :visible="createVisible" :title="'添加设备'" icon="fas fa-server" @close="createVisible=false">
      <div class="form-group">
        <label class="form-label">板卡MAC <span class="req">*</span></label>
        <input v-model="createForm.board_mac" class="form-control" @blur="handleCreateBoardMacBlur" placeholder="如: 00:1A:2B:3C:4D:5F" />
        <span v-if="createCustomNumberMode" class="custom-number-badge">自定义编号模式</span>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group">
          <label class="form-label">无线MAC <span class="req" v-show="!createCustomNumberMode">*</span></label>
          <input v-model="createForm.wireless_mac" class="form-control" :readonly="createCustomNumberMode" placeholder="如: 00:1A:2B:3C:4D:5F" />
        </div>
        <div class="form-group">
          <label class="form-label">IP地址 <span class="req" v-show="!createCustomNumberMode">*</span></label>
          <input v-model="createForm.ip_address" class="form-control" :readonly="createCustomNumberMode" placeholder="如: 192.168.1.100" />
        </div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group">
          <label class="form-label">状态</label>
          <select v-model="createForm.status" class="form-control" :disabled="createCustomNumberMode">
            <option value="normal">正常</option>
            <option value="fault">故障</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label">测试时间</label>
          <input v-model="createForm.test_date" type="datetime-local" class="form-control" />
        </div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group">
          <label class="form-label">操作员</label>
          <input v-model="createForm.operator" class="form-control" placeholder="操作员姓名" />
        </div>
      </div>
      <div class="form-group">
        <label class="form-label">故障原因 <span class="req" v-show="createForm.status==='fault' || createCustomNumberMode">*</span></label>
        <textarea v-model="createForm.fault_reason" class="form-control" placeholder="故障原因或现象描述"></textarea>
      </div>
      <div class="form-group">
        <label class="form-label">备注</label>
        <textarea v-model="createForm.notes" class="form-control" placeholder="备注信息（可选）"></textarea>
      </div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="createVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="saveCreateDevice">保存</button>
      </template>
    </Modal>

    <!-- Batch Status Modal -->
    <Modal :visible="batchStatusModalVisible" title="批量改状态" icon="fas fa-edit" @close="batchStatusModalVisible=false">
      <div class="form-group"><label class="form-label">新状态</label><select v-model="batchStatusForm.status" class="form-control"><option value="正常">正常</option><option value="故障">故障</option><option value="待处理">待处理</option></select></div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="batchStatusModalVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="applyBatchStatus">确认</button>
      </template>
    </Modal>

    <!-- Batch Disposal Modal -->
    <Modal :visible="batchDisposalModalVisible" title="批量改处置" icon="fas fa-edit" @close="batchDisposalModalVisible=false">
      <div class="form-group"><label class="form-label">处置方式</label><select v-model="batchDisposalForm.type" class="form-control"><option value="维修">维修</option><option value="报废">报废</option><option value="返厂">返厂</option></select></div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="batchDisposalModalVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="applyBatchDisposal">确认</button>
      </template>
    </Modal>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { deviceAPI, batchAPI } from '@/api'
import { useUiStore } from '@/stores/ui'
import { debounce } from '@/utils'
import Modal from '@/components/common/Modal.vue'

// MAC & IP validation
const MAC_REGEX = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/
const IP_REGEX = /^(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)){3}$/
const currentUser = ref(localStorage.getItem('display_name') || localStorage.getItem('username') || '')

const uiStore = useUiStore()
const devices = ref([])
const batches = ref([])
const page = ref(1); const totalPages = ref(1)
const search = ref(''); const filterStatus = ref(''); const filterBatch = ref('')
const selectedIds = ref([])
const allSelected = computed(() => devices.value.length > 0 && selectedIds.value.length === devices.value.length)

const debouncedSearch = debounce(() => loadDevices(1), 300)

// Edit form
const editVisible = ref(false)
const editForm = ref({ board_mac: '', wireless_mac: '', ip_address: '', status: 'normal', test_date: '', operator: currentUser.value, fault_reason: '', notes: '' })

// Create form
const createVisible = ref(false); const createCustomNumberMode = ref(false)
const createForm = ref({ board_mac: '', wireless_mac: '', ip_address: '', status: 'normal', test_date: '', operator: currentUser.value, fault_reason: '', notes: '' })

// Batch modals
const batchStatusModalVisible = ref(false); const batchStatusForm = ref({ status: '正常' })
const batchDisposalModalVisible = ref(false); const batchDisposalForm = ref({ type: '维修' })

onMounted(() => { loadDevices(); loadBatches() })

async function loadDevices(p = 1) {
  page.value = p
  try {
    const params = { page: p, per_page: 20 }
    if (search.value) params.search = search.value
    if (filterStatus.value) params.status = filterStatus.value
    if (filterBatch.value) params.batch_id = filterBatch.value
    const res = await deviceAPI.list(params); const d = res.data || res; devices.value = d.items || []; totalPages.value = d.total_pages || 1
  } catch { uiStore.notify('加载设备失败', 'error') }
}
async function loadBatches() {
  try { const res = await batchAPI.list({ per_page: 100 }); batches.value = (res.data||res).items||[] } catch {}
}
function dispStatus(s) {
  const m = { normal: '正常', fault: '故障', pending: '待处理', '正常': '正常', '故障': '故障', '待处理': '待处理' }
  return m[s] || s || '--'
}
function statusClass(s) { const m = { normal: 'status-normal', fault: 'status-fault', pending: 'status-pending', '正常': 'status-normal', '故障': 'status-fault', '待处理': 'status-pending' }; return m[s] || '' }
function toggleAll(e) { selectedIds.value = e.target.checked ? devices.value.map(d => d.id) : [] }

// Helper: datetime-local string
function getDefaultTestDate() {
  const now = new Date()
  const pad = n => String(n).padStart(2, '0')
  return `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`
}
function toLocalDateTimeStr(isoStr) {
  if (!isoStr) return getDefaultTestDate()
  const d = new Date(isoStr)
  if (isNaN(d.getTime())) return getDefaultTestDate()
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

// Create custom number mode
function handleCreateBoardMacBlur() {
  const val = createForm.value.board_mac.trim()
  if (val && !MAC_REGEX.test(val)) {
    createCustomNumberMode.value = true
    createForm.value.wireless_mac = '未知'
    createForm.value.ip_address = '未知'
    createForm.value.status = 'fault'
  } else if (MAC_REGEX.test(val)) {
    if (createForm.value.wireless_mac === '未知') createForm.value.wireless_mac = ''
    if (createForm.value.ip_address === '未知') createForm.value.ip_address = ''
    createCustomNumberMode.value = false
  }
}

// Edit device
function showEditModal(d) {
  editForm.value = {
    board_mac: d.board_mac || '',
    wireless_mac: d.wireless_mac || '',
    ip_address: d.ip_address || d.ip || '',
    status: d.status || 'normal',
    test_date: d.test_date ? toLocalDateTimeStr(d.test_date) : getDefaultTestDate(),
    operator: d.operator || d.tester || currentUser.value,
    fault_reason: d.fault_reason || '',
    notes: d.notes || d.remark || ''
  }
  editForm._id = d.id; editVisible.value = true
}
async function saveEdit() {
  const payload = {
    board_mac: editForm.value.board_mac.trim(), wireless_mac: editForm.value.wireless_mac.trim(),
    ip_address: editForm.value.ip_address.trim(), status: editForm.value.status,
    fault_reason: editForm.value.fault_reason.trim() || null, notes: editForm.value.notes.trim() || null,
    test_date: editForm.value.test_date ? new Date(editForm.value.test_date).toISOString() : null,
    operator: editForm.value.operator.trim() || null
  }
  try { await deviceAPI.update(editForm._id, payload); uiStore.notify('已更新', 'success'); editVisible.value = false; loadDevices() } catch {}
}

// Create device
function showCreateDevice() {
  createCustomNumberMode.value = false
  createForm.value = { board_mac: '', wireless_mac: '', ip_address: '', status: 'normal', test_date: getDefaultTestDate(), operator: currentUser.value, fault_reason: '', notes: '' }
  createVisible.value = true
}
async function saveCreateDevice() {
  const form = createForm.value; const isCustom = createCustomNumberMode.value; const errors = []
  if (!form.board_mac.trim()) errors.push('请输入板卡MAC地址')
  if (isCustom) {
    if (!form.fault_reason.trim()) errors.push('自定义编号模式下故障原因为必填')
  } else {
    if (!form.wireless_mac.trim()) errors.push('请输入无线MAC地址')
    else if (!MAC_REGEX.test(form.wireless_mac.trim())) errors.push('无线MAC格式无效')
    if (!form.ip_address.trim()) errors.push('请输入IP地址')
    else if (!IP_REGEX.test(form.ip_address.trim())) errors.push('IP地址格式无效')
  }
  if (errors.length) { uiStore.notify(errors.join('；'), 'error'); return }
  const payload = {
    board_mac: form.board_mac.trim(), wireless_mac: form.wireless_mac.trim(), ip_address: form.ip_address.trim(),
    status: form.status, fault_reason: form.fault_reason.trim() || null, notes: form.notes.trim() || null,
    test_date: form.test_date ? new Date(form.test_date).toISOString() : null,
    operator: form.operator.trim() || null
  }
  try { await deviceAPI.create(payload); uiStore.notify('已创建', 'success'); createVisible.value = false; loadDevices() } catch (e) { uiStore.notify(e.response?.data?.message || '操作失败', 'error') }
}

// Delete & batch
async function confirmDelete(d) {
  if (!confirm(`确认删除 ${d.board_mac}？`)) return
  try { await deviceAPI.delete(d.id); uiStore.notify('已删除', 'success'); loadDevices() } catch {}
}
async function applyBatchStatus() {
  try { await deviceAPI.batchUpdateStatus({ ids: selectedIds.value, status: batchStatusForm.value.status }); uiStore.notify('已更新', 'success'); batchStatusModalVisible.value = false; loadDevices() } catch {}
}
async function applyBatchDisposal() {
  try { await deviceAPI.batchUpdateDisposal({ ids: selectedIds.value, disposal_type: batchDisposalForm.value.type }); uiStore.notify('已更新', 'success'); batchDisposalModalVisible.value = false; loadDevices() } catch {}
}
async function confirmBatchDelete() {
  if (!confirm(`确认删除 ${selectedIds.value.length} 个设备？`)) return
  try { await deviceAPI.batchDelete({ ids: selectedIds.value }); uiStore.notify('已删除', 'success'); loadDevices() } catch {}
}
</script>

<style scoped>
.data-table { border-radius: var(--radius-md); overflow: hidden; }
.btn { transition: all 0.2s; }
.btn:hover { transform: translateY(-1px); }
.form-control { transition: all 0.25s ease; }
.form-control:focus { border-color: var(--color-primary); box-shadow: 0 0 0 2px var(--color-primary-dim), 0 0 12px rgba(var(--color-primary-rgb),0.15); }
.custom-number-badge { display: inline-flex; align-items: center; gap: 4px; margin-top: 4px; padding: 2px 8px; background: var(--color-warning); color: #fff; border-radius: 4px; font-size: 11px; font-weight: 600; }
.req { color: var(--color-error); font-weight: 400; }
</style>