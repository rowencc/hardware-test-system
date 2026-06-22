<template>
  <div v-if="authStore.isAuthenticated" class="app-layout">
    <AppSidebar />
    <header class="top-header">
      <div class="header-tabs">
        <div
          v-for="tab in tabs"
          :key="tab.path"
          class="header-tab"
          :class="{ active: currentPath === tab.path }"
          @click="switchTab(tab)"
        >
          <span class="header-tab-label">{{ tab.label }}</span>
          <button
            v-if="tab.closable"
            class="header-tab-close"
            @click.stop="closeTab(tab)"
          >&times;</button>
        </div>
      </div>
      <div class="header-right">
        <div class="header-user-avatar">{{ authStore.user?.display_name?.[0] || 'U' }}</div>
        <span class="header-user-name">{{ authStore.user?.display_name || authStore.user?.username }}</span>
        <span class="header-user-role">{{ authStore.user?.role === 'admin' ? 'ADMIN' : 'TESTER' }}</span>
        <button class="header-logout-btn" @click="handleLogout" title="退出登录">
          <i class="fas fa-sign-out-alt"></i>
        </button>
        <button class="header-theme-btn" @click="toggleTheme" :title="themeLabel">
          <i :class="themeIcon"></i>
        </button>
      </div>
    </header>
    <div class="main-content">
      <router-view />
    </div>
    <Notification />
  </div>
  <LoginOverlay v-else />
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from './stores/auth'
import AppSidebar from './components/layout/AppSidebar.vue'
import LoginOverlay from './components/common/LoginOverlay.vue'
import Notification from './components/common/Notification.vue'

const authStore = useAuthStore()
const route = useRoute()
const router = useRouter()

const routeLabelMap = {
  '/': '仪表盘',
  '/batches': '批次管理',
  '/devices': '设备管理',
  '/faults': '故障管理',
  '/returns': '返厂管理',
  '/settings': '系统设置',
  '/standards': '测试标准',
  '/users': '用户管理',
  '/help': '帮助文档',
}

function getLabel(path) {
  if (routeLabelMap[path]) return routeLabelMap[path]
  if (path.startsWith('/batches/')) return '批次详情'
  return path
}

const tabs = ref([{ path: '/', label: '仪表盘', closable: false }])
const currentPath = computed(() => route.path)

watch(currentPath, (path) => {
  if (!tabs.value.find(t => t.path === path)) {
    tabs.value.push({ path, label: getLabel(path), closable: true })
  }
}, { immediate: true })

function switchTab(tab) {
  if (tab.path !== currentPath.value) {
    router.push(tab.path)
  }
}

function closeTab(tab) {
  const idx = tabs.value.findIndex(t => t.path === tab.path)
  if (idx === -1 || !tab.closable) return
  tabs.value.splice(idx, 1)
  if (currentPath.value === tab.path) {
    const next = tabs.value[Math.min(idx, tabs.value.length - 1)]
    if (next) router.push(next.path)
  }
}

const themeIcon = ref('fas fa-moon')
const themeLabel = computed(() => {
  const current = document.documentElement.getAttribute('data-theme') || 'dark'
  return current === 'dark' ? '切换亮色主题' : '切换暗色主题'
})

function updateThemeIcon() {
  const current = document.documentElement.getAttribute('data-theme') || 'dark'
  themeIcon.value = current === 'dark' ? 'fas fa-sun' : 'fas fa-moon'
}

function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme') || 'dark'
  const next = current === 'dark' ? 'light' : 'dark'
  document.documentElement.setAttribute('data-theme', next)
  localStorage.setItem('theme', next)
  updateThemeIcon()
}

async function handleLogout() {
  await authStore.logout()
}

onMounted(() => {
  authStore.checkAuth()
  const theme = localStorage.getItem('theme') || 'dark'
  document.documentElement.setAttribute('data-theme', theme)
  updateThemeIcon()
})
</script>

<style scoped>
.header-tabs {
  display: flex;
  align-items: stretch;
  gap: 0;
  height: 100%;
  overflow-x: auto;
  flex: 1;
  min-width: 0;
}

.top-header {
  backdrop-filter: blur(20px) saturate(180%);
  background: rgba(var(--color-primary-rgb), 0.02);
  border-bottom: 1px solid var(--color-border);
  box-shadow: 0 1px 20px rgba(0,0,0,0.06);
}

.header-tab {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 0 16px;
  height: 100%;
  font-size: 12.5px;
  color: var(--color-text-3);
  cursor: pointer;
  border-right: 1px solid var(--color-border-subtle);
  white-space: nowrap;
  transition: all 0.2s ease;
  position: relative;
  flex-shrink: 0;
  user-select: none;
}

.header-tab:hover {
  background: var(--color-primary-dim);
  color: var(--color-text);
}

.header-tab.active {
  background: linear-gradient(180deg, var(--color-primary-dim), transparent);
  color: var(--color-primary);
  font-weight: 600;
  text-shadow: 0 0 8px rgba(var(--color-primary-rgb),0.3);
}

.header-tab.active::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 8px;
  right: 8px;
  height: 2px;
  background: var(--color-primary);
  border-radius: 2px 2px 0 0;
  animation: tabGlowIn 0.3s ease;
  box-shadow: 0 0 8px var(--color-primary);
}

@keyframes tabGlowIn {
  from { transform: scaleX(0); opacity: 0; }
  to { transform: scaleX(1); opacity: 1; }
}

.header-tab-label {
  max-width: 120px;
  overflow: hidden;
  text-overflow: ellipsis;
}

.header-tab-close {
  background: none;
  border: none;
  color: var(--color-text-3);
  font-size: 15px;
  line-height: 1;
  cursor: pointer;
  padding: 0 2px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  transition: all 0.25s ease;
}

.header-tab-close:hover {
  background: rgba(var(--color-error-rgb),0.15);
  color: var(--color-error);
  transform: rotate(90deg);
  box-shadow: 0 0 8px rgba(var(--color-error-rgb),0.3);
}

.header-right {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-shrink: 0;
  padding-left: 12px;
  margin-left: 8px;
}

.header-user-avatar {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: linear-gradient(135deg, var(--color-primary), var(--color-accent));
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  flex-shrink: 0;
  font-family: var(--font-mono);
}

.header-user-name {
  font-size: 12px;
  font-weight: 600;
  color: var(--color-text);
  white-space: nowrap;
}

.header-user-role {
  font-size: 10px;
  color: var(--color-primary);
  background: var(--color-primary-dim);
  padding: 2px 8px;
  border-radius: 10px;
  white-space: nowrap;
  font-family: var(--font-mono);
  letter-spacing: 0.5px;
  border: 1px solid rgba(var(--color-primary-rgb),0.12);
}

.header-theme-btn {
  background: none;
  border: 1px solid var(--color-border);
  color: var(--color-text-2);
  cursor: pointer;
  font-size: 15px;
  padding: 6px 8px;
  border-radius: var(--radius-sm);
  transition: all 0.25s ease;
  display: flex;
  align-items: center;
}

.header-theme-btn:hover {
  color: var(--color-primary);
  border-color: var(--color-primary);
  background: var(--color-primary-dim);
  transform: rotate(-15deg);
  box-shadow: 0 0 16px rgba(var(--color-primary-rgb),0.3);
}

.header-logout-btn {
  background: none;
  border: 1px solid var(--color-border);
  color: var(--color-text-2);
  cursor: pointer;
  font-size: 14px;
  padding: 6px 8px;
  border-radius: var(--radius-sm);
  transition: all 0.25s ease;
  display: flex;
  align-items: center;
}

.header-logout-btn:hover {
  color: var(--color-error);
  border-color: var(--color-error);
  background: rgba(var(--color-error-rgb),0.1);
  box-shadow: 0 0 12px rgba(var(--color-error-rgb),0.3);
}
</style>
