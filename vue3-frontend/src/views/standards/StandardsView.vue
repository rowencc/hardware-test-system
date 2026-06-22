<template>
  <div>
    <h1 class="page-title"><i class="fas fa-clipboard-list"></i> 测试标准管理</h1>

    <button class="btn btn-primary" style="margin-bottom:16px;" @click="showCreateModal">
      <i class="fas fa-plus"></i> 新建标准
    </button>

    <div v-for="std in standards" :key="std.id" class="standard-card" style="margin-bottom:14px;">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">
        <h4 style="font-size:14px;">{{ std.name }} <span style="font-size:12px;color:var(--color-text-3);font-weight:400;">— {{ std.description || '无描述' }}</span></h4>
        <div style="display:flex;gap:6px;">
          <button class="btn btn-sm btn-warning" @click="showEditModal(std)"><i class="fas fa-edit"></i> 编辑</button>
          <button class="btn btn-sm btn-error" @click="confirmDelete(std)"><i class="fas fa-trash"></i> 删除</button>
        </div>
      </div>
      <table class="data-table" v-if="std.metrics && std.metrics.length">
        <thead><tr><th>指标名称</th><th>类型</th><th>标准值</th><th>单位</th><th>说明</th></tr></thead>
        <tbody>
          <tr v-for="(m, i) in std.metrics" :key="i">
            <td>{{ m.name }}</td>
            <td>{{ m.type || 'pass-fail' }}</td>
            <td>{{ m.value || m.standard_value || '--' }}</td>
            <td>{{ m.unit || '--' }}</td>
            <td>{{ m.description || '--' }}</td>
          </tr>
        </tbody>
      </table>
      <div v-else style="font-size:12px;color:var(--color-text-3);">暂无指标</div>
    </div>
    <div v-if="!standards.length" class="empty-table"><i class="fas fa-clipboard-list"></i><p>暂无测试标准</p></div>

    <Modal :visible="modalVisible" :title="editingId ? '编辑标准' : '新建标准'" icon="fas fa-clipboard-list" @close="modalVisible=false" wide>
      <div class="form-group"><label class="form-label">标准名称</label><input v-model="form.name" class="form-control" /></div>
      <div class="form-group"><label class="form-label">描述</label><input v-model="form.description" class="form-control" /></div>
      <h5 style="font-size:13px;color:var(--color-text-2);margin-bottom:10px;">测试指标</h5>
      <div style="max-height:320px;overflow-y:auto;">
        <div v-for="(m, idx) in form.metrics" :key="idx" style="display:grid;grid-template-columns:2fr 1fr 1fr 1fr 32px;gap:6px;margin-bottom:8px;align-items:center;">
          <input v-model="m.name" class="form-control" placeholder="名称" style="font-size:12px;padding:6px 8px;" />
          <select v-model="m.type" class="form-control" style="font-size:12px;padding:4px 6px;"><option value="pass-fail">通过/不通过</option><option value="numeric">数值</option><option value="range">范围</option><option value="string">文本</option></select>
          <input v-model="m.standard_value" class="form-control" placeholder="标准值" style="font-size:12px;padding:6px 8px;" />
          <input v-model="m.unit" class="form-control" placeholder="单位" style="font-size:12px;padding:6px 8px;" />
          <button class="btn btn-xs btn-error" @click="form.metrics.splice(idx,1)" style="min-width:28px;height:28px;"><i class="fas fa-times"></i></button>
        </div>
      </div>
      <button class="btn btn-xs btn-secondary" @click="form.metrics.push({name:'',type:'pass-fail',standard_value:'',unit:''})" style="margin-top:6px;"><i class="fas fa-plus"></i> 添加指标</button>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="modalVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="saveStandard">保存</button>
      </template>
    </Modal>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { standardAPI } from '@/api'
import { useUiStore } from '@/stores/ui'
import Modal from '@/components/common/Modal.vue'

const uiStore = useUiStore()
const standards = ref([])
const modalVisible = ref(false); const editingId = ref(null)
const form = ref({ name: '', description: '', metrics: [] })

onMounted(() => loadStandards())

async function loadStandards() {
  try { const res = await standardAPI.list(); standards.value = (res.data || res || []).map(s => ({ ...s, metrics: s.metrics || [] })) } catch { uiStore.notify('加载标准失败', 'error') }
}
function showCreateModal() { editingId.value = null; form.value = { name: '', description: '', metrics: [{ name: '', type: 'pass-fail', standard_value: '', unit: '' }] }; modalVisible.value = true }
function showEditModal(std) { editingId.value = std.id; form.value = { name: std.name, description: std.description || '', metrics: (std.metrics || []).map(m => ({ ...m })) }; if (!form.value.metrics.length) form.value.metrics = [{ name: '', type: 'pass-fail', standard_value: '', unit: '' }]; modalVisible.value = true }
async function saveStandard() {
  try {
    if (editingId.value) { await standardAPI.update(editingId.value, form.value); uiStore.notify('标准已更新', 'success') }
    else { await standardAPI.create(form.value); uiStore.notify('标准已创建', 'success') }
    modalVisible.value = false; loadStandards()
  } catch (e) { uiStore.notify(e.response?.data?.message || '操作失败', 'error') }
}
async function confirmDelete(std) { if (!confirm(`确定要删除标准 "${std.name}" 吗？`)) return; try { await standardAPI.delete(std.id); uiStore.notify('标准已删除', 'success'); loadStandards() } catch {} }
</script>

<style scoped>
.standard-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: 20px;
  position: relative;
}
.standard-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 3px;
  height: 40px;
  background: var(--color-primary);
  border-radius: 0 2px 2px 0;
  box-shadow: 0 0 8px var(--color-primary);
}
.standard-card h4 { padding-left: 12px; }
.data-table { border-radius: var(--radius-md); overflow: hidden; }
.btn { transition: all 0.2s; }
.btn:hover { transform: translateY(-1px); }
.form-control { transition: all 0.25s ease; }
.form-control:focus { border-color: var(--color-primary); box-shadow: 0 0 0 2px var(--color-primary-dim), 0 0 12px rgba(var(--color-primary-rgb),0.15); }
.empty-table i { font-size: 40px; opacity: 0.2; }
</style>
