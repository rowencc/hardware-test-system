<template>
  <div>
    <h1 class="page-title"><i class="fas fa-cog"></i> 系统设置</h1>

    <div class="settings-grid">
    <div class="card">
      <h3 class="card-section-title">常规设置</h3>
      <div v-if="loading" style="text-align:center;padding:20px;color:var(--color-text-3);">加载中...</div>
      <template v-else>
        <div class="form-group">
          <label class="form-label">系统名称</label>
          <input v-model="config.system_name" class="form-control" />
        </div>
        <div class="form-group">
          <label class="form-label">公司名称</label>
          <input v-model="config.company_name" class="form-control" />
        </div>
        <div class="form-group">
          <label class="form-label">默认测试人员</label>
          <input v-model="config.default_tester" class="form-control" />
        </div>
        <div class="form-group">
          <label class="form-label">批次号前缀</label>
          <input v-model="config.batch_no_prefix" class="form-control" placeholder="如 BAT、TEST、HWT" style="max-width:240px;" />
          <div style="font-size:11px;color:var(--color-text-3);margin-top:4px;">自动生成的批次号格式：{前缀}-YYYYMMDD-{序号}，留空则默认为 "BAT"</div>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div class="form-group">
            <label class="form-label">每页显示条数</label>
            <input v-model.number="config.per_page" type="number" class="form-control" />
          </div>
          <div class="form-group">
            <label class="form-label">日期格式</label>
            <select v-model="config.date_format" class="form-control">
              <option value="YYYY-MM-DD">YYYY-MM-DD</option>
              <option value="MM/DD/YYYY">MM/DD/YYYY</option>
              <option value="DD/MM/YYYY">DD/MM/YYYY</option>
            </select>
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">用户管理</label>
          <div style="margin-bottom:8px;">
            <h4 style="font-size:13px;color:var(--color-text-2);margin-bottom:8px;">操作员列表</h4>
            <div v-for="(op, idx) in operators" :key="idx" style="display:flex;gap:6px;align-items:center;margin-bottom:4px;">
              <input v-model="operators[idx]" class="form-control" style="flex:1;" />
              <button class="btn btn-xs btn-error" @click="operators.splice(idx,1)"><i class="fas fa-times"></i></button>
            </div>
            <button class="btn btn-xs btn-secondary" @click="operators.push('')" style="margin-top:4px;"><i class="fas fa-plus"></i> 添加</button>
          </div>
        </div>
        <div style="margin-top:20px;display:flex;gap:10px;">
          <button class="btn btn-success" @click="saveConfig"><i class="fas fa-save"></i> 保存设置</button>
        </div>
      </template>
    </div>

    <div class="card" style="margin-top:20px;">
      <h3 class="card-section-title">快递100 授权配置</h3>
      <div class="form-group">
        <label class="form-label">Customer（企业ID）</label>
        <input v-model="config.kuaidi100_customer" class="form-control" placeholder="企业授权ID" />
      </div>
      <div class="form-group">
        <label class="form-label">Key（授权密钥）</label>
        <input v-model="config.kuaidi100_key" class="form-control" placeholder="API Key" />
      </div>
      <div class="form-group">
        <label class="form-label">Secret（密钥）</label>
        <input v-model="config.kuaidi100_secret" class="form-control" placeholder="API Secret" type="password" />
      </div>
      <div class="form-group">
        <label class="form-label">回调地址（可选）</label>
        <input v-model="config.kuaidi100_callback_url" class="form-control" placeholder="物流推送回调URL" />
      </div>
      <button class="btn btn-success" @click="saveConfig"><i class="fas fa-save"></i> 保存快递100配置</button>
    </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { configAPI, suggestAPI } from '@/api'
import { useUiStore } from '@/stores/ui'

const uiStore = useUiStore()
const config = ref({ system_name: '', company_name: '', default_tester: '', batch_no_prefix: 'BAT', per_page: 20, date_format: 'YYYY-MM-DD', kuaidi100_customer: '', kuaidi100_key: '', kuaidi100_secret: '', kuaidi100_callback_url: '' })
const operators = ref([])
const loading = ref(true)

onMounted(() => { loadConfig(); loadOperators() })

async function loadConfig() {
  try { const res = await configAPI.get(); const d = res.data || res; if (d) config.value = { ...config.value, ...d } } catch {}
  loading.value = false
}
async function loadOperators() {
  try { const res = await suggestAPI.operators(); const d = res.data || res || []; operators.value = d.map(o => typeof o === 'string' ? o : o.operator_name || o.name || '').filter(Boolean) } catch {}
}
async function saveConfig() {
  try { await configAPI.update(config.value); uiStore.notify('设置已保存', 'success') } catch { uiStore.notify('保存失败', 'error') }
}
</script>

<style scoped>
.settings-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(420px, 1fr));
  gap: 20px;
}
.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: 24px;
  position: relative;
  overflow: hidden;
}
.card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 2px;
  background: linear-gradient(90deg, var(--color-primary), var(--color-success), transparent);
  opacity: 0.4;
}
.card-section-title {
  font-size: 15px;
  font-weight: 700;
  margin-bottom: 20px;
  color: var(--color-primary);
  text-transform: uppercase;
  letter-spacing: 1px;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--color-border);
}
.form-control:focus {
  box-shadow: 0 0 0 2px var(--color-primary-dim), 0 0 12px rgba(var(--color-primary-rgb),0.15);
  border-color: var(--color-primary);
}
.btn-success:hover {
  box-shadow: 0 0 20px rgba(var(--color-success-rgb),0.4);
  transform: translateY(-1px);
}
.form-group { margin-bottom: 18px; }
.form-label { margin-bottom: 8px; font-size: 13px; }
</style>
