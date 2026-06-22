<template>
  <div>
    <h1 class="page-title"><i class="fas fa-exclamation-triangle"></i> 故障管理</h1>

    <div style="display:flex;gap:10px;margin-bottom:16px;flex-wrap:wrap;align-items:center;">
      <input v-model="search" class="form-control" placeholder="搜索MAC..." style="width:200px;" @input="debouncedSearch" />
      <select v-model="filterDisposal" class="form-control" style="width:140px;" @change="loadFaults(1)"><option value="">全部处置</option><option value="维修">维修</option><option value="报废">报废</option><option value="返厂">返厂</option></select>
    </div>

    <table class="data-table">
      <thead><tr><th>设备MAC</th><th>批次</th><th>故障说明</th><th>处置方式</th><th>快递信息</th><th>责任人</th><th>操作</th></tr></thead>
      <tbody>
        <tr v-for="f in faults" :key="f.id">
          <td><code>{{ f.board_mac }}</code></td>
          <td>{{ f.batch_no || '--' }}</td>
          <td>{{ f.fault_desc || '--' }}</td>
          <td><span class="status-badge" :class="disposalClass(f.disposal_type)">{{ f.disposal_type || '--' }}</span></td>
          <td>
            <span v-if="f.tracking_no" style="cursor:pointer;color:var(--color-primary);" @click="queryLogistics(f.tracking_no);logisticsVisible=true">{{ f.courier ? f.courier+' ' : '' }}{{ f.tracking_no }}</span>
            <span v-else>--</span>
          </td>
          <td>{{ f.responsible || '--' }}</td>
          <td class="actions-cell">
            <button class="btn btn-xs btn-warning" @click="showEditModal(f)"><i class="fas fa-edit"></i></button>
            <button class="btn btn-xs btn-error" @click="confirmDelete(f)"><i class="fas fa-trash"></i></button>
          </td>
        </tr>
        <tr v-if="!faults.length"><td colspan="7" class="empty-table"><i class="fas fa-exclamation-triangle"></i><p>暂无故障</p></td></tr>
      </tbody>
    </table>

    <div class="pagination" v-if="totalPages > 1">
      <button class="btn btn-sm btn-secondary" :disabled="page<=1" @click="loadFaults(page-1)">上一页</button>
      <span style="font-size:12px;color:var(--color-text-3);">第 {{ page }} / {{ totalPages }} 页</span>
      <button class="btn btn-sm btn-secondary" :disabled="page>=totalPages" @click="loadFaults(page+1)">下一页</button>
    </div>

    <Modal :visible="editVisible" title="编辑故障" icon="fas fa-exclamation-triangle" @close="editVisible=false" wide>
      <div class="form-group"><label class="form-label">故障说明</label><input v-model="editForm.fault_desc" class="form-control" /></div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group"><label class="form-label">处置方式</label><select v-model="editForm.disposal_type" class="form-control"><option value="维修">维修</option><option value="报废">报废</option><option value="返厂">返厂</option></select></div>
        <div class="form-group"><label class="form-label">责任人</label><input v-model="editForm.responsible" class="form-control" /></div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        <div class="form-group"><label class="form-label">快递公司</label><input v-model="editForm.courier" class="form-control" /></div>
        <div class="form-group"><label class="form-label">快递单号</label><input v-model="editForm.tracking_no" class="form-control" /></div>
      </div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="editVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="saveEdit">保存</button>
      </template>
    </Modal>

    <Modal :visible="logisticsVisible" title="物流查询" icon="fas fa-truck" @close="logisticsVisible=false" wide>
      <div style="display:flex;gap:8px;margin-bottom:14px;">
        <input v-model="trackingQuery" class="form-control" placeholder="输入快递单号" style="flex:1;" />
        <button class="btn btn-primary btn-sm" @click="queryLogistics(trackingQuery)">查询</button>
      </div>
      <div v-if="logisticsLoading" style="text-align:center;padding:20px;color:var(--color-text-3);">查询中...</div>
      <div v-else-if="logisticsResult" style="max-height:300px;overflow-y:auto;">
        <div v-if="logisticsResult.state" style="font-size:13px;margin-bottom:10px;">
          <strong>{{ logisticsResult.nu || trackingQuery }}</strong>
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
import { faultAPI, logisticsAPI } from '@/api'
import { useUiStore } from '@/stores/ui'
import { debounce } from '@/utils'
import Modal from '@/components/common/Modal.vue'

const uiStore = useUiStore()
const faults = ref([])
const page = ref(1); const totalPages = ref(1)
const search = ref(''); const filterDisposal = ref('')
const debouncedSearch = debounce(() => loadFaults(1), 300)

const editVisible = ref(false); const editForm = ref({ fault_desc: '', disposal_type: '维修', responsible: '', courier: '', tracking_no: '' })
const logisticsVisible = ref(false); const trackingQuery = ref(''); const logisticsLoading = ref(false); const logisticsResult = ref(null)

onMounted(() => loadFaults())

async function loadFaults(p = 1) {
  page.value = p
  try {
    const params = { page: p, per_page: 20 }
    if (search.value) params.search = search.value
    if (filterDisposal.value) params.disposal_type = filterDisposal.value
    const res = await faultAPI.list(params); const d = res.data || res; faults.value = d.items || []; totalPages.value = d.total_pages || 1
  } catch { uiStore.notify('加载故障失败', 'error') }
}
function disposalClass(s) { const m = { '维修': 'status-warning', '报废': 'status-error', '返厂': 'status-returned' }; return m[s] || '' }
function showEditModal(f) { editForm.value = { fault_desc: f.fault_desc, disposal_type: f.disposal_type, responsible: f.responsible || '', courier: f.courier || '', tracking_no: f.tracking_no || '' }; editForm._id = f.id; editVisible.value = true }
async function saveEdit() {
  try { await faultAPI.update(editForm._id, editForm.value); uiStore.notify('已更新', 'success'); editVisible.value = false; loadFaults() } catch {}
}
async function confirmDelete(f) {
  if (!confirm(`确认删除故障记录？`)) return
  try { await faultAPI.delete(f.id); uiStore.notify('已删除', 'success'); loadFaults() } catch {}
}
async function queryLogistics(tn) {
  if (!tn) return; logisticsLoading.value = true; logisticsResult.value = null; trackingQuery.value = tn
  try { const res = await logisticsAPI.query(tn); logisticsResult.value = res.data || res || null } catch {}
  logisticsLoading.value = false
}
</script>

<style scoped>
.data-table { border-radius: var(--radius-md); overflow: hidden; }
.btn { transition: all 0.2s; }
.btn:hover { transform: translateY(-1px); }
.form-control { transition: all 0.25s ease; }
.form-control:focus { border-color: var(--color-primary); box-shadow: 0 0 0 2px var(--color-primary-dim), 0 0 12px rgba(var(--color-primary-rgb),0.15); }
</style>
