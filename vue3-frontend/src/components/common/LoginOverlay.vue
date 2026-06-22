<template>
  <div class="login-overlay">
    <canvas ref="particleCanvas" class="particle-canvas"></canvas>
    <div class="center-glow"></div>
    <div class="login-card">
      <div class="login-glow"></div>
      <div class="login-icon">
        <i class="fas fa-microchip"></i>
      </div>
      <h2>硬件测试记录系统</h2>
      <p>Hardware Test Recording System</p>
      <form @submit.prevent="handleLogin">
        <div class="form-group">
          <label class="form-label"><i class="fas fa-user"></i> 用户名</label>
          <input v-model="username" class="form-control" placeholder="输入用户名" required autofocus />
        </div>
        <div class="form-group">
          <label class="form-label"><i class="fas fa-lock"></i> 密码</label>
          <input v-model="password" type="password" class="form-control" placeholder="输入密码" required />
        </div>
        <p v-if="error" class="login-error"><i class="fas fa-exclamation-circle"></i> {{ error }}</p>
        <button type="submit" class="btn btn-primary login-btn" :disabled="loading">
          <span v-if="!loading">进 入 系 统</span>
          <span v-else class="spinner"></span>
        </button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const username = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)
const particleCanvas = ref(null)

async function handleLogin() {
  error.value = ''
  loading.value = true
  try {
    await authStore.login(username.value, password.value)
  } catch (e) {
    error.value = e.response?.data?.message || '登录失败，请检查用户名和密码'
  } finally {
    loading.value = false
  }
}

// Particle system
let animId = null
let particles = []
const PARTICLE_COUNT = 80
const CONNECT_DIST = 120

function initParticles(canvas) {
  const ctx = canvas.getContext('2d')
  const resize = () => {
    canvas.width = window.innerWidth
    canvas.height = window.innerHeight
  }
  resize()
  window.addEventListener('resize', resize)

  particles = Array.from({ length: PARTICLE_COUNT }, () => ({
    x: Math.random() * canvas.width,
    y: Math.random() * canvas.height,
    vx: (Math.random() - 0.5) * 0.6,
    vy: (Math.random() - 0.5) * 0.6,
    r: Math.random() * 2 + 1,
    alpha: Math.random() * 0.5 + 0.2
  }))

  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height)

    const cx = canvas.width / 2
    const cy = canvas.height / 2

    for (let i = 0; i < particles.length; i++) {
      const p = particles[i]
      p.x += p.vx
      p.y += p.vy
      if (p.x < 0) p.x = canvas.width
      if (p.x > canvas.width) p.x = 0
      if (p.y < 0) p.y = canvas.height
      if (p.y > canvas.height) p.y = 0

      // Brightness boost near center
      const dx = p.x - cx, dy = p.y - cy
      const dist = Math.sqrt(dx * dx + dy * dy)
      const glowFactor = Math.max(0, 1 - dist / 400)
      const alpha = p.alpha + glowFactor * 0.6

      // Draw particle
      ctx.beginPath()
      ctx.arc(p.x, p.y, p.r + glowFactor * 2, 0, Math.PI * 2)
      ctx.fillStyle = `rgba(0,240,255,${Math.min(alpha, 1)})`
      ctx.fill()

      // Connections
      for (let j = i + 1; j < particles.length; j++) {
        const q = particles[j]
        const ndx = p.x - q.x
        const ndy = p.y - q.y
        const nd = Math.sqrt(ndx * ndx + ndy * ndy)
        if (nd < CONNECT_DIST) {
          const lineAlpha = (1 - nd / CONNECT_DIST) * 0.15
          ctx.beginPath()
          ctx.moveTo(p.x, p.y)
          ctx.lineTo(q.x, q.y)
          ctx.strokeStyle = `rgba(0,240,255,${lineAlpha})`
          ctx.lineWidth = 0.5
          ctx.stroke()
        }
      }
    }
    animId = requestAnimationFrame(draw)
  }

  draw()
}

onMounted(() => {
  if (particleCanvas.value) initParticles(particleCanvas.value)
})

onUnmounted(() => {
  if (animId) cancelAnimationFrame(animId)
})
</script>

<style scoped>
.login-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  width: 100vw;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: radial-gradient(ellipse at 50% 50%, #0d1a30 0%, #070810 50%, #03040a 100%);
  overflow: hidden;
}

.particle-canvas {
  position: absolute;
  inset: 0;
  z-index: 0;
}

/* Center radial highlight */
.center-glow {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 700px;
  height: 700px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(0,240,255,0.08) 0%, rgba(0,240,255,0.03) 30%, rgba(255,0,255,0.02) 60%, transparent 100%);
  pointer-events: none;
  z-index: 1;
}

/* Login card */
.login-card {
  position: relative;
  z-index: 2;
  width: 420px;
  max-width: 92vw;
  padding: 42px 38px 36px;
  backdrop-filter: blur(28px) saturate(200%);
  -webkit-backdrop-filter: blur(28px) saturate(200%);
  background: linear-gradient(160deg, rgba(10,22,48,0.85) 0%, rgba(6,14,32,0.92) 40%, rgba(4,8,20,0.95) 100%);
  border: 1px solid rgba(0,240,255,0.25);
  border-radius: 16px;
  box-shadow:
    0 0 60px rgba(0,0,0,0.7),
    0 0 120px rgba(0,240,255,0.08),
    inset 0 1px 0 rgba(0,240,255,0.05);
  animation: cardEnter 0.6s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes cardEnter {
  from {
    opacity: 0;
    transform: translateY(20px) scale(0.96);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

/* Top neon line */
.login-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 16px;
  right: 16px;
  height: 1.5px;
  background: linear-gradient(90deg, transparent, rgba(0,240,255,0.8), rgba(255,0,255,0.6), rgba(0,240,255,0.8), transparent);
  box-shadow: 0 0 16px rgba(0,240,255,0.4), 0 0 32px rgba(255,0,255,0.2);
}

/* Inner card glow */
.login-glow {
  position: absolute;
  top: -60px;
  left: 50%;
  transform: translateX(-50%);
  width: 260px;
  height: 120px;
  background: radial-gradient(ellipse, rgba(0,240,255,0.12) 0%, transparent 70%);
  pointer-events: none;
}

/* Icon */
.login-icon {
  width: 56px;
  height: 56px;
  margin: 0 auto 18px;
  border-radius: 14px;
  background: linear-gradient(135deg, rgba(0,240,255,0.15), rgba(255,0,255,0.1));
  border: 1px solid rgba(0,240,255,0.3);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 0 24px rgba(0,240,255,0.15);
}
.login-icon i {
  font-size: 26px;
  color: var(--color-primary);
  text-shadow: 0 0 16px rgba(0,240,255,0.6);
  animation: iconPulse 3s ease-in-out infinite;
}

@keyframes iconPulse {
  0%, 100% { text-shadow: 0 0 16px rgba(0,240,255,0.4); }
  50% { text-shadow: 0 0 28px rgba(0,240,255,0.8), 0 0 48px rgba(255,0,255,0.3); }
}

/* Title */
.login-card h2 {
  font-size: 22px;
  font-weight: 700;
  text-align: center;
  margin-bottom: 6px;
  background: linear-gradient(135deg, var(--color-primary), #80d0ff, var(--color-accent));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  letter-spacing: 0.5px;
}

.login-card > p {
  text-align: center;
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--color-text-3);
  margin-bottom: 30px;
  letter-spacing: 1.5px;
  text-transform: uppercase;
}

/* Form */
.form-group {
  margin-bottom: 16px;
}

.form-label {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  font-weight: 600;
  color: var(--color-text-2);
  margin-bottom: 6px;
  letter-spacing: 0.5px;
  text-transform: uppercase;
}

.form-label i {
  font-size: 11px;
  color: var(--color-primary);
  opacity: 0.7;
}

.form-control {
  width: 100%;
  padding: 11px 14px;
  background: rgba(0,0,0,0.35);
  border: 1px solid rgba(0,240,255,0.15);
  border-radius: 10px;
  color: var(--color-text);
  font-size: 14px;
  font-family: var(--font-mono);
  outline: none;
  transition: all 0.3s ease;
  box-sizing: border-box;
}

.form-control::placeholder {
  color: rgba(126,184,218,0.3);
}

.form-control:focus {
  border-color: var(--color-primary);
  background: rgba(0,0,0,0.5);
  box-shadow: 0 0 0 3px rgba(0,240,255,0.08), 0 0 20px rgba(0,240,255,0.15);
}

/* Error */
.login-error {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--color-error);
  font-size: 12px;
  margin: 0 0 14px;
  padding: 8px 12px;
  background: rgba(255,51,102,0.08);
  border: 1px solid rgba(255,51,102,0.2);
  border-radius: 8px;
  font-family: var(--font-mono);
}

.login-error i {
  font-size: 14px;
}

/* Button */
.login-btn {
  width: 100%;
  justify-content: center;
  padding: 13px;
  font-size: 14px;
  font-weight: 700;
  letter-spacing: 3px;
  border-radius: 10px;
  border: 1px solid rgba(0,240,255,0.4);
  background: linear-gradient(135deg, rgba(0,240,255,0.15), rgba(0,180,220,0.2));
  color: var(--color-primary);
  cursor: pointer;
  transition: all 0.35s cubic-bezier(0.16, 1, 0.3, 1);
  position: relative;
  overflow: hidden;
}

.login-btn::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, rgba(0,240,255,0), rgba(0,240,255,0.1), rgba(255,0,255,0.05));
  opacity: 0;
  transition: opacity 0.35s ease;
}

.login-btn:hover:not(:disabled) {
  background: linear-gradient(135deg, rgba(0,240,255,0.25), rgba(0,200,240,0.3));
  border-color: rgba(0,240,255,0.7);
  box-shadow: 0 0 30px rgba(0,240,255,0.3), 0 0 60px rgba(0,240,255,0.1);
  transform: translateY(-2px);
  color: #fff;
}

.login-btn:hover:not(:disabled)::after {
  opacity: 1;
}

.login-btn:active:not(:disabled) {
  transform: translateY(0);
}

.login-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Spinner */
.spinner {
  display: inline-block;
  width: 18px;
  height: 18px;
  border: 2px solid rgba(0,240,255,0.2);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>
