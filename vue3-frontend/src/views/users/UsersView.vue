<template>
  <div>
    <h1 class="page-title"><i class="fas fa-users"></i> 用户管理</h1>

    <button class="btn btn-primary" style="margin-bottom:16px;" @click="showCreateModal"><i class="fas fa-plus"></i> 新建用户</button>

    <table class="data-table">
      <thead><tr><th>ID</th><th>用户名</th><th>显示名称</th><th>角色</th><th>创建时间</th><th>操作</th></tr></thead>
      <tbody>
        <tr v-for="u in users" :key="u.id">
          <td>{{ u.id }}</td>
          <td><strong>{{ u.username }}</strong></td>
          <td>{{ u.display_name || '--' }}</td>
          <td><span class="status-badge" :class="u.role==='admin'?'status-completed':'status-in_progress'">{{ u.role === 'admin' ? '管理员' : '测试员' }}</span></td>
          <td style="font-size:12px;">{{ formatDateTime(u.created_at) }}</td>
          <td class="actions-cell">
            <button class="btn btn-sm btn-warning" @click="showEditModal(u)"><i class="fas fa-edit"></i></button>
            <button class="btn btn-sm btn-secondary" @click="showPasswordModal(u)"><i class="fas fa-key"></i></button>
            <button class="btn btn-sm btn-error" @click="confirmDelete(u)"><i class="fas fa-trash"></i></button>
          </td>
        </tr>
        <tr v-if="!users.length"><td colspan="6" class="empty-table"><i class="fas fa-users"></i><p>暂无用户</p></td></tr>
      </tbody>
    </table>

    <Modal :visible="editModalVisible" :title="editingId ? '编辑用户' : '新建用户'" icon="fas fa-user" @close="editModalVisible=false">
      <div class="form-group"><label class="form-label">用户名</label><input v-model="editForm.username" class="form-control" /></div>
      <div class="form-group"><label class="form-label">显示名称</label><input v-model="editForm.display_name" class="form-control" /></div>
      <div class="form-group" v-if="!editingId"><label class="form-label">密码</label><input v-model="editForm.password" type="password" class="form-control" /></div>
      <div class="form-group"><label class="form-label">角色</label>
        <select v-model="editForm.role" class="form-control"><option value="tester">测试员</option><option value="admin">管理员</option></select>
      </div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="editModalVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="saveUser">保存</button>
      </template>
    </Modal>

    <Modal :visible="passwordModalVisible" title="修改密码" icon="fas fa-key" @close="passwordModalVisible=false">
      <div class="form-group"><label class="form-label">新密码</label><input v-model="newPassword" type="password" class="form-control" /></div>
      <template #footer>
        <button class="btn btn-sm btn-secondary" @click="passwordModalVisible=false">取消</button>
        <button class="btn btn-sm btn-primary" @click="changePassword">确认修改</button>
      </template>
    </Modal>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { userAPI } from '@/api'
import { useUiStore } from '@/stores/ui'
import { formatDateTime } from '@/utils'
import Modal from '@/components/common/Modal.vue'

const uiStore = useUiStore()
const users = ref([])
const editModalVisible = ref(false); const editingId = ref(null)
const editForm = ref({ username: '', display_name: '', password: '', role: 'tester' })
const passwordModalVisible = ref(false); const passwordUserId = ref(null); const newPassword = ref('')

onMounted(() => loadUsers())

async function loadUsers() { try { const res = await userAPI.list(); users.value = res.data || res || [] } catch { uiStore.notify('加载用户失败', 'error') } }
function showCreateModal() { editingId.value = null; editForm.value = { username: '', display_name: '', password: '', role: 'tester' }; editModalVisible.value = true }
function showEditModal(u) { editingId.value = u.id; editForm.value = { username: u.username, display_name: u.display_name || '', password: '', role: u.role || 'tester' }; editModalVisible.value = true }
async function saveUser() {
  try {
    if (editingId.value) { await userAPI.update(editingId.value, { username: editForm.value.username, display_name: editForm.value.display_name, role: editForm.value.role }); uiStore.notify('用户已更新', 'success') }
    else { if (!editForm.value.password) { uiStore.notify('请输入密码', 'warning'); return }; await userAPI.create(editForm.value); uiStore.notify('用户已创建', 'success') }
    editModalVisible.value = false; loadUsers()
  } catch (e) { uiStore.notify(e.response?.data?.message || '操作失败', 'error') }
}
function showPasswordModal(u) { passwordUserId.value = u.id; newPassword.value = ''; passwordModalVisible.value = true }
async function changePassword() { if (!newPassword.value) { uiStore.notify('请输入新密码', 'warning'); return }; try { await userAPI.updatePassword(passwordUserId.value, { password: newPassword.value }); uiStore.notify('密码已修改', 'success'); passwordModalVisible.value = false } catch {} }
async function confirmDelete(u) { if (!confirm(`确定要删除用户 "${u.username}" 吗？`)) return; try { await userAPI.delete(u.id); uiStore.notify('用户已删除', 'success'); loadUsers() } catch {} }
</script>

<style scoped>
.data-table { border-radius: var(--radius-md); overflow: hidden; }
.btn { transition: all 0.2s; }
.btn:hover { transform: translateY(-1px); }
.form-control { transition: all 0.25s ease; }
.form-control:focus { border-color: var(--color-primary); box-shadow: 0 0 0 2px var(--color-primary-dim), 0 0 12px rgba(var(--color-primary-rgb),0.15); }
.empty-table i { font-size: 40px; opacity: 0.2; }
</style>
