<template>
  <teleport to="body">
    <div v-if="visible" class="modal-overlay" @click.self="$emit('close')">
      <div class="modal-card" :class="{ wide }" :style="{ maxWidth: maxWidth }">
        <div class="modal-corner-tl"></div>
        <div class="modal-corner-tr"></div>
        <div class="modal-corner-bl"></div>
        <div class="modal-corner-br"></div>
        <div class="modal-header">
          <h3><i :class="icon"></i> {{ title }}</h3>
          <button class="modal-close" @click="$emit('close')">&times;</button>
        </div>
        <div class="modal-body">
          <slot />
        </div>
        <div class="modal-footer" v-if="$slots.footer">
          <slot name="footer" />
        </div>
      </div>
    </div>
  </teleport>
</template>

<script setup>
defineProps({
  visible: Boolean,
  title: String,
  icon: { type: String, default: 'fas fa-file' },
  wide: Boolean,
  maxWidth: { type: String, default: '' }
})
defineEmits(['close'])
</script>

<style scoped>
.modal-overlay {
  backdrop-filter: blur(6px);
  background: rgba(0,0,0,0.6);
  animation: cyberFadeIn 0.2s ease;
}
@keyframes cyberFadeIn { from { opacity: 0; } to { opacity: 1; } }

.modal-card {
  background: var(--color-surface);
  border: 1px solid rgba(var(--color-primary-rgb),0.3);
  box-shadow:
    var(--shadow-lg),
    0 0 60px rgba(var(--color-primary-rgb),0.08),
    inset 0 1px 0 rgba(var(--color-primary-rgb),0.05);
  animation: cyberModalIn 0.3s cubic-bezier(0.16,1,0.3,1);
  position: relative;
  overflow: hidden;
  backdrop-filter: blur(20px) saturate(180%);
}
@keyframes cyberModalIn {
  from { transform: scale(0.92) translateY(20px); opacity: 0; }
  to { transform: scale(1) translateY(0); opacity: 1; }
}

/* Four corner L-shaped decorations */
.modal-corner-tl,
.modal-corner-tr,
.modal-corner-bl,
.modal-corner-br {
  position: absolute;
  width: 18px;
  height: 18px;
  z-index: 2;
  pointer-events: none;
  opacity: 0.5;
}
.modal-corner-tl {
  top: 0; left: 0;
  border-top: 2px solid var(--color-primary);
  border-left: 2px solid var(--color-primary);
  border-radius: 14px 0 0 0;
}
.modal-corner-tr {
  top: 0; right: 0;
  border-top: 2px solid var(--color-primary);
  border-right: 2px solid var(--color-primary);
  border-radius: 0 14px 0 0;
}
.modal-corner-bl {
  bottom: 0; left: 0;
  border-bottom: 2px solid var(--color-primary);
  border-left: 2px solid var(--color-primary);
  border-radius: 0 0 0 14px;
}
.modal-corner-br {
  bottom: 0; right: 0;
  border-bottom: 2px solid var(--color-primary);
  border-right: 2px solid var(--color-primary);
  border-radius: 0 0 14px 0;
}

.modal-header {
  background: linear-gradient(180deg, rgba(var(--color-primary-rgb),0.05), transparent);
  border-bottom: 1px solid rgba(var(--color-primary-rgb),0.2);
}
.modal-header h3 {
  font-size: 15px;
  font-weight: 700;
  text-shadow: 0 0 8px rgba(var(--color-primary-rgb),0.3);
}
.modal-close {
  border-radius: 50%;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.25s ease;
  border: 1px solid rgba(var(--color-error-rgb),0.2);
  background: none;
  color: var(--color-text-3);
  font-size: 18px;
  cursor: pointer;
}
.modal-close:hover {
  background: rgba(var(--color-error-rgb),0.15);
  color: var(--color-error);
  border-color: var(--color-error);
  box-shadow: 0 0 12px rgba(var(--color-error-rgb),0.4);
  transform: rotate(90deg);
}
.modal-body {
  padding: 24px;
}
.modal-body :deep(.form-control:focus) {
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-dim), 0 0 12px rgba(var(--color-primary-rgb),0.2);
}
.modal-footer {
  background: var(--color-surface-2);
  border-top: 1px solid rgba(var(--color-primary-rgb),0.2);
}
</style>
