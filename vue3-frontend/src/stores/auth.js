import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authAPI } from '@/api'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const isAuthenticated = computed(() => !!user.value)

  function setUser(u) { user.value = u }
  function clearUser() { user.value = null }

  async function checkAuth() {
    try {
      const res = await authAPI.me()
      setUser(res.data || res)
    } catch {
      clearUser()
    }
  }

  async function login(username, password) {
    await authAPI.login(username, password)
    await checkAuth()
  }

  async function logout() {
    try { await authAPI.logout() } catch {}
    clearUser()
  }

  return { user, isAuthenticated, setUser, clearUser, checkAuth, login, logout }
})
