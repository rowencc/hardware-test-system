import { createRouter, createWebHashHistory } from 'vue-router'
import DashboardView from '@/views/dashboard/DashboardView.vue'
import BatchListView from '@/views/batches/BatchListView.vue'
import BatchDetailView from '@/views/batches/BatchDetailView.vue'
import DeviceListView from '@/views/devices/DeviceListView.vue'
import FaultListView from '@/views/faults/FaultListView.vue'
import ReturnListView from '@/views/returns/ReturnListView.vue'
import SettingsView from '@/views/settings/SettingsView.vue'
import StandardsView from '@/views/standards/StandardsView.vue'
import UsersView from '@/views/users/UsersView.vue'
import HelpView from '@/views/help/HelpView.vue'

const routes = [
  { path: '/', name: 'dashboard', component: DashboardView },
  { path: '/batches', name: 'batches', component: BatchListView },
  { path: '/batches/:id', name: 'batchDetail', component: BatchDetailView, props: true },
  { path: '/devices', name: 'devices', component: DeviceListView },
  { path: '/faults', name: 'faults', component: FaultListView },
  { path: '/returns', name: 'returns', component: ReturnListView },
  { path: '/settings', name: 'settings', component: SettingsView },
  { path: '/standards', name: 'standards', component: StandardsView },
  { path: '/users', name: 'users', component: UsersView },
  { path: '/help', name: 'help', component: HelpView },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

export default router
