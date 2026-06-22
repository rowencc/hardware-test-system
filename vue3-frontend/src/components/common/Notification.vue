<template>
  <div class="notification-container">
    <div v-for="n in uiStore.notifications" :key="n.id"
      class="notification" :class="'notification-' + n.type">
      <i :class="iconMap[n.type] || 'fas fa-info-circle'"></i>
      {{ n.message }}
    </div>
  </div>
</template>

<script setup>
import { useUiStore } from '@/stores/ui'
const uiStore = useUiStore()
const iconMap = { success: 'fas fa-check-circle', error: 'fas fa-times-circle', warning: 'fas fa-exclamation-circle', info: 'fas fa-info-circle' }
</script>

<style scoped>
.notification-container {
  gap: 10px;
}
.notification {
  backdrop-filter: blur(16px) saturate(180%);
  padding: 14px 22px;
  border-radius: var(--radius-md);
  font-size: 13px;
  font-weight: 500;
  box-shadow: 0 8px 32px rgba(0,0,0,0.25);
  display: flex;
  align-items: center;
  gap: 10px;
  animation: notifSlideIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);
  min-width: 300px;
  border: 1px solid rgba(255,255,255,0.1);
}
@keyframes notifSlideIn {
  from { transform: translateX(120%); opacity: 0; }
  to { transform: none; opacity: 1; }
}
.notification i { font-size: 16px; flex-shrink: 0; }
.notification-success {
  background: linear-gradient(135deg, rgba(16,185,129,0.9), rgba(16,185,129,0.75));
  color: #fff;
}
.notification-error {
  background: linear-gradient(135deg, rgba(239,68,68,0.9), rgba(239,68,68,0.75));
  color: #fff;
}
.notification-warning {
  background: linear-gradient(135deg, rgba(245,158,11,0.9), rgba(245,158,11,0.75));
  color: #1e293b;
}
.notification-info {
  background: linear-gradient(135deg, rgba(14,165,233,0.9), rgba(14,165,233,0.75));
  color: #fff;
}
</style>
