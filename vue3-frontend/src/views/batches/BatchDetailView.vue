<template>
  <div>
    <h1 class="page-title"><i class="fas fa-list-alt"></i> 批次详情 — {{ batch.batch_no }}</h1>

    <!-- KPI Cards -->
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:20px;">
      <div class="stat-card"><div class="stat-value" style="color:var(--color-primary);">{{ batchStats.total }}</div><div class="stat-label">设备总数</div></div>
      <div class="stat-card"><div class="stat-value" style="color:var(--color-success);">{{ batchStats.normal }}</div><div class="stat-label">正常</div></div>
      <div class="stat-card"><div class="stat-value" style="color:var(--color-error);">{{ batchStats.fault }}</div><div class="stat-label">故障</div></div>
      <div class="stat-card"><div class="stat-value" style="color:var(--color-warning);">{{ batchStats.pending }}</div><div class="stat-label">待处理</div></div>
    </div>

    <!-- Progress -->
    <div style="margin-bottom:16px;">
      <div style="display:flex;justify-content:space-between;font-size:12px;color:var(--color-text-3);margin-bottom:6px;">
        <span>进度</span><span>{{ Math.round(batchStats.progress) }}%</span>
      </div>
      <div style="height:6px;background:var(--color-bg);border-radius:6px;overflow:hidden;">
        <div :style="{width:batchStats.progress+'%',height:'100%',borderRadius:'6px',background:'linear-gradient(90deg,var(--color-primary),var(--color-success))',boxShadow:'0 0 10px var(--color-primary)',transition:'width 0.5s ease'}"></div>
      </div>
    </div>

    <!-- Batch operations -->
    <div style="display:flex;flex-wrap:wrap;gap:6px;margin-bottom:14px;">
      <button class="btn btn-sm btn-primary" @click="showCreateDevice"><i class="fas fa-plus"></i> 添加设备</button>
      <button class="btn btn-sm btn-secondary" :disabled="!selectedIds.length" @click="batchStatusModalVisible=true">批量改状态</button>
      <button class="btn btn-sm btn-secondary" :disabled="!selectedIds.length" @click="batchDisposalModalVisible=true">批量改处置</button>
      <button class="btn btn-sm btn-secondary" @click="showBatchMetricModal"><i class="fas fa-edit"></i> 批量改指标</button>
      <button class="btn btn-sm btn-primary" @click="exportExcel"><i class="fas fa-download"></i> 导出Excel</button>
      <button class="btn btn-sm btn-error" :disabled="!selectedIds.length" @click="confirmBatchDelete">批量删除</button>
    </div>

    <table class="data-table">
      <thead><tr>
        <th class="col-check"><input type="checkbox" @change="toggleAll($event)" :checked="allSelected"></th>
        <th v-for="col in visibleColumns" :key="col.key">{{ col.label }}</th>
        <th>操作</th>
      </tr></thead>
      <tbody>
        <tr v-for="d in devices" :key="d.id">
          <td class="col-check"><input type="checkbox" :value="d.id" v-model="selectedIds"></td>
          <td v-for="col in visibleColumns" :key="col.key">
            <template v-if="col.key === 'board_mac'"><code>{{ d.board_mac }}</code></template>
            <template v-else-if="col.key === 'wireless_mac'"><code>{{ d.wireless_mac || '--' }}</code></template>
            <template v-else-if="col.key === 'status'"><span class="status-badge" :class="statusClass(d.status)">{{ dispStatus(d.status) }}</span></template>
            <template v-else-if="col.key === 'fault_disposition'"><span class="status-badge" :class="disposalClass(d.fault_disposition)">{{ dispDisposal(d.fault_disposition) }}</span></template>
            <template v-else>{{ d[col.key] || '--' }}</template>
          </td>
          <td class="actions-cell">
            <button class="btn btn-xs btn-warning" @click="showEditDevice(d)"><i class="fas fa-edit"></i></button>
            <button class="btn btn-xs btn-error" @click="showFaultModal(d)"><i class="fas fa-exclamation-triangle"></i></button>
            <button class="btn btn-xs btn-error" @click="confirmDelete(d)"><i class="fas fa-trash"></i></button>
          </td>
        </tr>
        <tr v-if="!devices.length"><td :colspan="visibleColumns.length+2" class="empty-table"><i class="fas fa-server"></i><p>暂无设备</p></td></tr>
      </tbody>
    </table>

    <!-- Create/Edit Device Modal -->
    <Modal :visible="createVisible" :title="editingDeviceId ? '编辑设备' : '添加设备'" icon="fas fa-server" @close="createVisible=false" wide>
      <!-- Tabs (only for create, not edit) -->
      <div v-if="!editingDeviceId" class="modal-tabs" style="display:flex;gap:0;margin-bottom:20px;border-bottom:1px solid var(--color-border);">
        <button class="modal-tab" :class="{active: activeTab === 'single'}" @click="activeTab='single';importResult=null;importPreview=[]" style="padding:8px 20px;background:none;border:none;border-bottom:2px solid transparent;color:var(--color-text-3);font-size:13px;cursor:pointer;transition:all .2s;">单个添加</button>
        <button class="modal-tab" :class="{active: activeTab === 'batch'}" @click="activeTab='batch';importResult=null;importPreview=[]" style="padding:8px 20px;background:none;border:none;border-bottom:2px solid transparent;color:var(--color-text-3);font-size:13px;cursor:pointer;transition:all .2s;">批量导入</button>
      </div>

      <!-- Single Add Tab -->
      <div v-show="activeTab === 'single' || editingDeviceId">
        <div class="form-group">
          <label class="form-label">板卡MAC <span class="req">*</span></label>
          <input v-model="deviceForm.board_mac" class="form-control" @blur="handleBoardMacBlur" placeholder="如: 00:1A:2B:3C:4D:5F" />
          <span v-if="customNumberMode" class="custom-number-badge">自定义编号模式</span>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div class="form-group">
            <label class="form-label">无线MAC <span class="req" v-show="!customNumberMode">*</span></label>
            <input v-model="deviceForm.wireless_mac" class="form-control" :readonly="customNumberMode" placeholder="如: 00:1A:2B:3C:4D:5F" />
          </div>
          <div class="form-group">
            <label class="form-label">IP地址 <span class="req" v-show="!customNumberMode">*</span></label>
            <input v-model="deviceForm.ip_address" class="form-control" :readonly="customNumberMode" placeholder="如: 192.168.1.100" />
          </div>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div class="form-group">
            <label class="form-label">状态</label>
            <select v-model="deviceForm.status" class="form-control" :disabled="customNumberMode">
              <option value="normal">正常</option>
              <option value="fault">故障</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">测试时间</label>
            <input v-model="deviceForm.test_date" type="datetime-local" class="form-control" />
          </div>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div class="form-group">
            <label class="form-label">操作员</label>
            <input v-model="deviceForm.operator" class="form-control" placeholder="操作员姓名" />
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">故障处置</label>
          <select v-model="deviceForm.fault_disposition" class="form-control">
            <option value="">-- 无 --</option>
            <option value="待返厂">待返厂</option>
            <option value="返厂中">返厂中</option>
            <option value="已返厂">已返厂</option>
          </select>
        </div>
        <div class="form-group" v-if="deviceForm.fault_disposition==='返厂中'">
          <label class="form-label">返厂单编号</label>
          <div style="padding:8px 12px;background:var(--color-bg);border-radius:var(--radius-sm);color:var(--color-text-2);font-size:13px;">{{ deviceForm.fault_return_tracking || '--' }}</div>
        </div>
        <div class="form-group">
          <label class="form-label">故障原因 <span class="req" v-show="deviceForm.status==='fault' || customNumberMode">*</span></label>
          <textarea v-model="deviceForm.fault_reason" class="form-control" placeholder="故障原因或现象描述"></textarea>
        </div>
        <div class="form-group">
          <label class="form-label">备注</label>
          <textarea v-model="deviceForm.notes" class="form-control" placeholder="备注信息（可选）"></textarea>
        </div>
      </div>

      <!-- Batch Import Tab -->
      <div v-show="activeTab === 'batch' && !editingDeviceId">
        <div style="margin-bottom:16px;">
          <p style="font-size:13px;color:var(--color-text-2);margin-bottom:12px;">下载批量导入模板，按格式填写设备信息后上传。</p>
          <a :href="exportAPI.template()" download class="btn btn-sm btn-secondary" style="display:inline-flex;align-items:center;gap:6px;text-decoration:none;">
            <i class="fas fa-download"></i> 下载导入模板
          </a>
        </div>
        <div class="form-group" style="border:2px dashed var(--color-border);border-radius:var(--radius-md);padding:24px;text-align:center;">
          <input type="file" ref="fileInput" accept=".xlsx,.xls" @change="handleImportFile" style="display:none;" />
          <button class="btn btn-primary" @click="$refs.fileInput.click()" :disabled="importLoading">
            <i class="fas fa-upload"></i> 选择上传文件
          </button>
          <p style="font-size:11px;color:var(--color-text-3);margin-top:8px;">支持 .xlsx / .xls 格式</p>
        </div>
        <div v-if="importFile" style="margin-top:12px;font-size:12px;color:var(--color-text-2);">
          已选择: {{ importFile.name }} ({{ (importFile.size/1024).toFixed(1) }} KB)
        </div>
        <div v-if="importPreview.length" style="margin-top:16px;">
          <div style="font-size:13px;font-weight:600;color:var(--color-primary);margin-bottom:8px;">
            预览 (共 {{ importPreview.length }} 条)
          </div>
          <div style="max-height:200px;overflow-y:auto;border:1px solid var(--color-border);border-radius:var(--radius-sm);">
            <table class="data-table" style="font-size:11px;">
              <thead><tr><th>板卡MAC</th><th>无线MAC</th><th>IP地址</th><th>操作员</th><th>状态</th></tr></thead>
              <tbody>
                <tr v-for="(item, i) in importPreview.slice(0, 10)" :key="i">
                  <td><code>{{ item.board_mac }}</code></td>
                  <td><code>{{ item.wireless_mac || '--' }}</code></td>
                  <td>{{ item.ip_address || '--' }}</td>
                  <td>{{ item.operator || '--' }}</td>
                  <td>{{ item.status === 'fault' ? '故障' : '正常' }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-if="importPreview.length > 10" style="font-size:11px;color:var(--color-text-3);margin-top:4px;">仅显示前 10 条...</p>
        </div>
        <div v-if="importResult" style="margin-top:14px;padding:12px;border-radius:var(--radius-sm);font-size:13px;"
          :style="{background: importResult.failed ? 'rgba(248,113,113,.08)' : 'rgba(52,211,153,.08)', border: '1px solid '+(importResult.failed?'rgba(248,113,113,.2)':'rgba(52,211,153,.2)')}">
          <i class="fas" :class="importResult.failed ? 'fa-exclamation-circle' : 'fa-check-circle'"
            :style="{color: importResult.failed ? 'var(--color-error)' : 'var(--color-success)'}"></i>
          成功 {{ importResult.success }} 条<template v-if="importResult.failed">，失败 {{ importResult.failed }} 条</template>。
          <div v-if="importResult.errors && importResult.errors.length" style="margin-top:6px;font-size:11px;color:var(--color-error);">
            <div v-for="(err, i) in importResult.errors" :key="i">{{ err }}</div>
          </div>
        </div>
      </div>

      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="createVisible=false">取消</button>
        <button v-if="(!editingDeviceId && activeTab==='single') || editingDeviceId" class="btn btn-sm btn-primary" @click="saveDevice">保存</button>
        <button v-if="!editingDeviceId && activeTab==='batch'" class="btn btn-sm btn-primary" @click="executeBatchImport" :disabled="!importPreview.length || importLoading">
          <i class="fas fa-upload"></i> {{ importLoading ? '导入中...' : '开始导入' }}
        </button>
      </template>
    </Modal>

    <!-- Fault Modal -->
    <Modal :visible="faultVisible" title="报备故障" icon="fas fa-exclamation-triangle" @close="faultVisible=false" wide>
      <div class="form-group"><label class="form-label">MAC: {{ faultDevice?.board_mac }}</label></div>
      <div class="form-group"><label class="form-label">故障说明</label><input v-model="faultForm.fault_desc" class="form-control" /></div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group"><label class="form-label">处置方式</label><select v-model="faultForm.disposal_type" class="form-control"><option value="维修">维修</option><option value="报废">报废</option><option value="返厂">返厂</option></select></div>
        <div class="form-group"><label class="form-label">责任人</label><input v-model="faultForm.responsible" class="form-control" /></div>
      </div>
      <div v-if="faultForm.disposal_type==='返厂'" style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group"><label class="form-label">快递公司</label><input v-model="faultForm.courier" class="form-control" /></div>
        <div class="form-group"><label class="form-label">快递单号</label><input v-model="faultForm.tracking_no" class="form-control" /></div>
      </div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="faultVisible=false">取消</button>
        <button class="btn btn-sm btn-error" @click="reportFault">确认报备</button>
      </template>
    </Modal>

    <!-- Batch Status Modal -->
    <Modal :visible="batchStatusModalVisible" title="批量修改状态" icon="fas fa-edit" @close="batchStatusModalVisible=false">
      <div class="form-group"><label class="form-label">新状态</label><select v-model="batchStatusForm.status" class="form-control"><option value="正常">正常</option><option value="故障">故障</option><option value="待处理">待处理</option></select></div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="batchStatusModalVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="applyBatchStatus">确认</button>
      </template>
    </Modal>

    <!-- Batch Disposal Modal -->
    <Modal :visible="batchDisposalModalVisible" title="批量修改处置方式" icon="fas fa-edit" @close="batchDisposalModalVisible=false">
      <div class="form-group"><label class="form-label">处置方式</label><select v-model="batchDisposalForm.type" class="form-control"><option value="维修">维修</option><option value="报废">报废</option><option value="返厂">返厂</option><option value="入库">入库</option></select></div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="batchDisposalModalVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="applyBatchDisposal">确认</button>
      </template>
    </Modal>

    <!-- Batch Metric Modal -->
    <Modal :visible="batchMetricVisible" title="批量修改测试指标" icon="fas fa-edit" @close="batchMetricVisible=false" wide>
      <div v-for="(m,idx) in metricForm.metrics" :key="idx" style="display:grid;grid-template-columns:2fr 1fr 1fr 1fr 30px;gap:6px;margin-bottom:8px;align-items:center;">
        <input v-model="m.name" class="form-control" placeholder="指标名称" style="font-size:12px;" />
        <select v-model="m.type" class="form-control" style="font-size:12px;"><option value="pass-fail">通过/不通过</option><option value="numeric">数值</option><option value="range">范围</option><option value="string">文本</option></select>
        <input v-model="m.value" class="form-control" placeholder="默认值" style="font-size:12px;" />
        <input v-model="m.unit" class="form-control" placeholder="单位" style="font-size:12px;" />
        <button class="btn btn-xs btn-error" @click="metricForm.metrics.splice(idx,1)"><i class="fas fa-times"></i></button>
      </div>
      <button class="btn btn-xs btn-secondary" @click="metricForm.metrics.push({name:'',type:'pass-fail',value:'',unit:''})"><i class="fas fa-plus"></i> 添加</button>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="batchMetricVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="applyBatchMetric">应用</button>
      </template>
    </Modal>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { batchAPI, deviceAPI, faultAPI, exportAPI } from '@/api'
import { useUiStore } from '@/stores/ui'
import { useAuthStore } from '@/stores/auth'
import { debounce } from '@/utils'
import * as XLSX from 'xlsx'
import Modal from '@/components/common/Modal.vue'

const route = useRoute()
const uiStore = useUiStore()
const authStore = useAuthStore()
const batch = ref({})
const devices = ref([])
const selectedIds = ref([])
const batchStats = computed(() => {
  const total = devices.value.length; const normal = devices.value.filter(d => d.status === 'normal' || d.status === '正常').length
  const fault = devices.value.filter(d => d.status === 'fault' || d.status === '故障').length; const pending = devices.value.filter(d => d.status === 'pending' || d.status === '待处理').length
  let progress = 0; if (total > 0) progress = ((normal + fault) / total) * 100
  return { total, normal, fault, pending, progress }
})

const metricColumns = ref([])
const visibleColumns = computed(() => {
  const base = [{ key: 'board_mac', label: '板卡MAC' }, { key: 'wireless_mac', label: '无线MAC' }, { key: 'ip_address', label: 'IP地址' }, { key: 'operator', label: '操作员' }, { key: 'status', label: '状态' }, { key: 'fault_disposition', label: '处置' }]
  const mids = metricColumns.value.map((m, i) => ({ key: `metric_${i}`, label: m.name }))
  return [...base, ...mids]
})
const allSelected = computed(() => devices.value.length > 0 && selectedIds.value.length === devices.value.length)

// MAC & IP validation
const MAC_REGEX = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/
const IP_REGEX = /^(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)){3}$/

// Device form
const createVisible = ref(false); const editingDeviceId = ref(null); const customNumberMode = ref(false)
const activeTab = ref('single')
const currentUser = computed(() => authStore.user?.display_name || authStore.user?.username || localStorage.getItem('display_name') || localStorage.getItem('username') || '')
const deviceForm = ref({ board_mac: '', wireless_mac: '', ip_address: '', status: 'normal', test_date: '', operator: currentUser.value, fault_reason: '', notes: '' })

// Batch import
const importFile = ref(null)
const importPreview = ref([])
const importLoading = ref(false)
const importResult = ref(null)

// Helper: datetime-local string
function getDefaultTestDate() {
  const now = new Date()
  const pad = n => String(n).padStart(2, '0')
  return `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`
}
function toLocalDateTimeStr(isoStr) {
  if (!isoStr) return getDefaultTestDate()
  // 兼容 macOS Safari 等对含毫秒 Z 后缀 ISO 字符串解析不佳的环境
  const normalized = isoStr.replace(/\.\d{3}Z$/, '').replace('Z', '')
  const d = new Date(normalized)
  if (isNaN(d.getTime())) return getDefaultTestDate()
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

// Custom number mode
function handleBoardMacBlur() {
  const val = deviceForm.value.board_mac.trim()
  if (val && !MAC_REGEX.test(val)) { applyCustomNumberMode() }
  else if (MAC_REGEX.test(val)) { resetMacMode() }
}
function applyCustomNumberMode() {
  customNumberMode.value = true
  deviceForm.value.wireless_mac = '未知'
  deviceForm.value.ip_address = '未知'
  deviceForm.value.status = 'fault'
}
function resetMacMode() {
  if (deviceForm.value.wireless_mac === '未知') deviceForm.value.wireless_mac = ''
  if (deviceForm.value.ip_address === '未知') deviceForm.value.ip_address = ''
  customNumberMode.value = false
}

// Fault form
const faultVisible = ref(false); const faultDevice = ref(null)
const faultForm = ref({ fault_desc: '', disposal_type: '维修', responsible: '', courier: '', tracking_no: '' })

// Batch modals
const batchStatusModalVisible = ref(false); const batchStatusForm = ref({ status: '正常' })
const batchDisposalModalVisible = ref(false); const batchDisposalForm = ref({ type: '维修' })
const batchMetricVisible = ref(false); const metricForm = ref({ metrics: [] })

onMounted(async () => {
  try {
    const res = await batchAPI.get(route.params.id); batch.value = res.data || res
    if (batch.value.metrics) metricColumns.value = batch.value.metrics.map(m => ({ name: m.name, type: m.type }))
    loadDevices()
  } catch { uiStore.notify('加载批次失败', 'error') }
})

async function loadDevices() {
  try {
    const res = await deviceAPI.list({ batch_id: route.params.id, per_page: 500 })
    devices.value = (res.data || res).items || res.data || res || []
  } catch {}
}

function dispStatus(s) {
  const m = { normal: '正常', fault: '故障', pending: '待处理', '正常': '正常', '故障': '故障', '待处理': '待处理' }
  return m[s] || s || '--'
}
function statusClass(s) {
  const m = { normal: 'status-normal', fault: 'status-fault', pending: 'status-pending', '正常': 'status-normal', '故障': 'status-fault', '待处理': 'status-pending' }; return m[s] || ''
}
function dispDisposal(d) {
  const m = { '待返厂': '待返厂', '返厂中': '返厂中', '已返厂': '已返厂', pending: '待处理', stored: '已入库' }
  return m[d] || d || '--'
}
function disposalClass(d) {
  const m = { '待返厂': 'status-pending', '返厂中': 'status-in_progress', '已返厂': 'status-completed', pending: 'status-pending', stored: 'status-stored' }; return m[d] || ''
}
function toggleAll(e) {
  selectedIds.value = e.target.checked ? devices.value.map(d => d.id) : []
}

// Device CRUD
function showCreateDevice() {
  editingDeviceId.value = null; customNumberMode.value = false; activeTab.value = 'single'
  importFile.value = null; importPreview.value = []; importResult.value = null
  deviceForm.value = { board_mac: '', wireless_mac: '', ip_address: '', status: 'normal', test_date: getDefaultTestDate(), operator: currentUser.value, fault_reason: '', notes: '' }
  createVisible.value = true
}
function showEditDevice(d) {
  editingDeviceId.value = d.id; customNumberMode.value = false
  deviceForm.value = {
    board_mac: d.board_mac || '',
    wireless_mac: d.wireless_mac || '',
    ip_address: d.ip_address || d.ip || '',
    status: d.status || 'normal',
    test_date: d.test_date ? toLocalDateTimeStr(d.test_date) : getDefaultTestDate(),
    operator: d.operator || d.tester || currentUser.value,
    fault_reason: d.fault_reason || '',
    notes: d.notes || d.remark || '',
    fault_disposition: d.fault_disposition || '',
    fault_return_tracking: d.fault_return_tracking || ''
  }
  createVisible.value = true
}
async function saveDevice() {
  const form = deviceForm.value; const isCustom = customNumberMode.value; const errors = []
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
    status: form.status, fault_disposition: form.fault_disposition || null,
    fault_reason: form.fault_reason.trim() || null, notes: form.notes.trim() || null,
    test_date: form.test_date ? new Date(form.test_date).toISOString() : null,
    operator: form.operator.trim() || null
  }
  try {
    if (editingDeviceId.value) { await deviceAPI.update(editingDeviceId.value, payload); uiStore.notify('已更新', 'success') }
    else { await deviceAPI.create({ ...payload, batch_id: batch.value.id }); uiStore.notify('已创建', 'success') }
    createVisible.value = false; loadDevices()
  } catch (e) { uiStore.notify(e.response?.data?.message || '操作失败', 'error') }
}
async function confirmDelete(d) {
  if (!confirm(`确认删除设备 ${d.board_mac}？`)) return
  try { await deviceAPI.delete(d.id); uiStore.notify('已删除', 'success'); loadDevices() } catch {}
}

// Batch import
function handleImportFile(e) {
  importResult.value = null; importPreview.value = []
  const file = e.target.files[0]
  if (!file) return
  importFile.value = file
  const reader = new FileReader()
  reader.onload = (ev) => {
    try {
      const data = new Uint8Array(ev.target.result)
      const wb = XLSX.read(data, { type: 'array' })
      const ws = wb.Sheets[wb.SheetNames[0]]
      const rows = XLSX.utils.sheet_to_json(ws, { header: 1 })
      if (!rows.length || rows.length < 2) {
        uiStore.notify('文件中没有有效数据', 'error')
        return
      }
      // Map headers (first row) to fields
      const headers = rows[0].map(h => String(h || '').trim())
      const colMap = {}
      headers.forEach((h, i) => {
        const l = h.toLowerCase()
        if (l.includes('板卡') || l.includes('board_mac')) colMap.board_mac = i
        else if (l.includes('无线') || l.includes('wireless')) colMap.wireless_mac = i
        else if (l.includes('ip') || l.includes('地址')) colMap.ip_address = i
        else if (l.includes('操作员') || l.includes('operator')) colMap.operator = i
        else if (l.includes('状态') || l.includes('status')) colMap.status = i
        else if (l.includes('故障') || l.includes('fault')) colMap.fault_reason = i
        else if (l.includes('备注') || l.includes('note')) colMap.notes = i
      })
      if (colMap.board_mac === undefined) {
        uiStore.notify('文件中未找到板卡MAC列', 'error')
        return
      }
      const items = []
      for (let r = 1; r < rows.length; r++) {
        const row = rows[r]
        if (!row || row.every(c => !c)) continue
        const item = {
          board_mac: String(row[colMap.board_mac] || '').trim(),
          wireless_mac: colMap.wireless_mac !== undefined ? String(row[colMap.wireless_mac] || '').trim() : '',
          ip_address: colMap.ip_address !== undefined ? String(row[colMap.ip_address] || '').trim() : '',
          operator: colMap.operator !== undefined ? String(row[colMap.operator] || '').trim() : (currentUser.value || ''),
          status: colMap.status !== undefined ? (String(row[colMap.status] || '').trim() === '正常' ? 'normal' : 'fault') : 'normal',
          fault_reason: colMap.fault_reason !== undefined ? String(row[colMap.fault_reason] || '').trim() : '',
          notes: colMap.notes !== undefined ? String(row[colMap.notes] || '').trim() : ''
        }
        if (item.board_mac) items.push(item)
      }
      importPreview.value = items
    } catch (err) {
      uiStore.notify('解析文件失败: ' + err.message, 'error')
    }
  }
  reader.readAsArrayBuffer(file)
}

async function executeBatchImport() {
  if (!importPreview.value.length) return
  importLoading.value = true
  try {
    const payload = importPreview.value.map(item => ({
      ...item,
      test_date: new Date().toISOString()
    }))
    await deviceAPI.batchCreate({ batch_id: batch.value.id, items: payload })
    importResult.value = { success: importPreview.value.length, failed: 0, errors: [] }
    uiStore.notify(`成功导入 ${importPreview.value.length} 个设备`, 'success')
    setTimeout(() => { createVisible.value = false; loadDevices() }, 800)
  } catch (e) {
    const msg = e.response?.data?.message || e.message || '批量导入失败'
    importResult.value = { success: 0, failed: importPreview.value.length, errors: [msg] }
    uiStore.notify(msg, 'error')
  } finally {
    importLoading.value = false
  }
}

// Fault
function showFaultModal(d) { faultDevice.value = d; faultForm.value = { fault_desc: '', disposal_type: '维修', responsible: '', courier: '', tracking_no: '' }; faultVisible.value = true }
async function reportFault() {
  try {
    await faultAPI.create({ ...faultForm.value, device_id: faultDevice.value.id })
    uiStore.notify('故障已报备', 'success'); faultVisible.value = false; loadDevices()
  } catch (e) { uiStore.notify(e.response?.data?.message || '操作失败', 'error') }
}

// Batch operations
async function applyBatchStatus() {
  try {
    await deviceAPI.batchUpdate({ ids: selectedIds.value, field: 'status', value: batchStatusForm.value.status })
    uiStore.notify('状态已更新', 'success'); batchStatusModalVisible.value = false; loadDevices()
  } catch (e) { uiStore.notify(e.response?.data?.message || '操作失败', 'error') }
}
async function applyBatchDisposal() {
  try {
    await deviceAPI.batchUpdate({ ids: selectedIds.value, field: 'fault_disposition', value: batchDisposalForm.value.type })
    uiStore.notify('已更新', 'success'); batchDisposalModalVisible.value = false; loadDevices()
  } catch (e) { uiStore.notify(e.response?.data?.message || '操作失败', 'error') }
}
function showBatchMetricModal() { metricForm.value.metrics = metricColumns.value.map(m => ({ name: m.name, type: m.type, value: '', unit: '' })); batchMetricVisible.value = true }
async function applyBatchMetric() {
  try {
    await batchAPI.update(batch.value.id, { metrics: metricForm.value.metrics.filter(m => m.name.trim()) })
    metricColumns.value = metricForm.value.metrics.filter(m => m.name.trim()).map(m => ({ name: m.name, type: m.type }))
    uiStore.notify('指标已更新', 'success'); batchMetricVisible.value = false; loadDevices()
  } catch (e) { uiStore.notify(e.response?.data?.message || '操作失败', 'error') }
}
async function confirmBatchDelete() {
  if (!confirm(`确认删除 ${selectedIds.value.length} 个设备？`)) return
  try { await deviceAPI.batchDelete({ ids: selectedIds.value }); uiStore.notify('已删除', 'success'); loadDevices() } catch {}
}
async function exportExcel() {
  try { await deviceAPI.exportExcel({ batch_id: batch.value.id }); uiStore.notify('导出成功', 'success') } catch {}
}
</script>

<style scoped>
.data-table { border-radius: var(--radius-md); overflow: hidden; }
.stat-card { text-align: left; }
.stat-card .stat-value { font-size: 26px; font-weight: 800; font-family: var(--font-mono); padding-left: 12px; }
.stat-card .stat-label { font-size: 11px; color: var(--color-text-3); padding-left: 12px; text-transform: uppercase; letter-spacing: 1px; font-weight: 600; }
.btn { transition: all 0.2s; }
.btn:hover { transform: translateY(-1px); }
.form-control { transition: all 0.25s ease; }
.form-control:focus { border-color: var(--color-primary); box-shadow: 0 0 0 2px var(--color-primary-dim), 0 0 12px rgba(var(--color-primary-rgb),0.15); }
.custom-number-badge { display: inline-flex; align-items: center; gap: 4px; margin-top: 4px; padding: 2px 8px; background: var(--color-warning); color: #fff; border-radius: 4px; font-size: 11px; font-weight: 600; }
.req { color: var(--color-error); font-weight: 400; }
.modal-tab.active { color: var(--color-primary) !important; border-bottom-color: var(--color-primary) !important; font-weight: 600; }
</style>