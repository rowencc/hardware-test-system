<template>
  <aside class="sidebar" :class="{ open: sidebarOpen }">
    <div class="sidebar-logo">
      <i class="fas fa-microchip"></i>
      <span>硬件测试系统</span>
    </div>
    <nav class="sidebar-nav">
      <template v-for="group in navGroups" :key="group.title">
        <div class="nav-group-title">{{ group.title }}</div>
        <div class="nav-group">
          <button
            v-for="item in group.items"
            :key="item.section"
            class="nav-item"
            :class="{ active: currentRoute === item.route }"
            @click="navigate(item.route)"
          >
            <i :class="item.icon"></i>
            <span>{{ item.label }}</span>
          </button>
        </div>
      </template>
    </nav>
  </aside>
</template>

<script setup>
import { computed, ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const sidebarOpen = ref(false)

const currentRoute = computed(() => route.path)

const allItems = [
  { section: 'dashboard', route: '/', icon: 'fas fa-chart-pie', label: '仪表盘', group: '仪表盘' },
  { section: 'batches', route: '/batches', icon: 'fas fa-layer-group', label: '批次管理', group: '测试管理' },
  { section: 'devices', route: '/devices', icon: 'fas fa-server', label: '设备管理', group: '测试管理' },
  { section: 'faults', route: '/faults', icon: 'fas fa-exclamation-triangle', label: '故障管理', group: '测试管理' },
  { section: 'returns', route: '/returns', icon: 'fas fa-truck', label: '返厂管理', group: '测试管理' },
  { section: 'settings', route: '/settings', icon: 'fas fa-cog', label: '系统设置', group: '系统配置' },
  { section: 'standards', route: '/standards', icon: 'fas fa-clipboard-list', label: '测试标准', group: '系统配置' },
  { section: 'users', route: '/users', icon: 'fas fa-users', label: '用户管理', group: '系统配置', adminOnly: true },
  { section: 'help', route: '/help', icon: 'fas fa-question-circle', label: '帮助文档', group: '其他' },
]

const navGroups = computed(() => {
  const filtered = allItems.filter(item => !item.adminOnly || authStore.user?.role === 'admin')
  const grouped = {}
  for (const item of filtered) {
    const g = item.group
    if (!grouped[g]) grouped[g] = []
    grouped[g].push(item)
  }
  return Object.entries(grouped).map(([title, items]) => ({ title, items }))
})

function navigate(path) {
  router.push(path)
}
</script>

<style scoped>
.sidebar {
  backdrop-filter: blur(20px) saturate(180%);
  background: linear-gradient(180deg, rgba(10,20,40,0.92) 0%, rgba(5,12,28,0.95) 100%);
  border-right: 1px solid var(--color-border);
}
[data-theme="light"] .sidebar {
  background: linear-gradient(180deg, rgba(255,255,255,0.95), rgba(248,250,252,0.95));
}
.sidebar-logo {
  background: linear-gradient(135deg, rgba(var(--color-primary-rgb),0.08), transparent);
}
.nav-group {
  margin-bottom: 2px;
}
.nav-group-title {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 1.5px;
  color: var(--color-text-3);
  padding: 10px 14px 4px;
  margin-top: 4px;
  border-top: 1px solid var(--color-border-subtle);
}
.nav-group-title:first-child {
  border-top: none;
  margin-top: 0;
}
.nav-item {
  position: relative;
  overflow: hidden;
}
.nav-item::before {
  content: '';
  position: absolute;
  left: 0;
  top: 50%;
  transform: translateY(-50%);
  width: 3px;
  height: 0;
  background: var(--color-primary);
  border-radius: 0 2px 2px 0;
  transition: height 0.25s ease;
  box-shadow: 0 0 8px var(--color-primary);
}
.nav-item.active::before {
  height: 60%;
}
.nav-item:hover {
  transform: translateX(2px);
}
.nav-item i {
  transition: transform 0.25s ease;
}
.nav-item:hover i {
  transform: scale(1.15);
}
.nav-item.active i {
  text-shadow: 0 0 10px rgba(var(--color-primary-rgb),0.6);
}
</style>
