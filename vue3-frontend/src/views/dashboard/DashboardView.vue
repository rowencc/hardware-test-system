<template>
  <div>
    <h1 class="page-title"><i class="fas fa-chart-pie"></i> 仪表盘</h1>

    <!-- Stats -->
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px;margin-bottom:24px;">
      <div class="stat-card"><div class="stat-value" style="color:var(--color-primary);">{{ stats.totalDevices }}</div><div class="stat-label">总设备</div></div>
      <div class="stat-card" style="--accent:#00ff88;"><div class="stat-value" style="color:var(--color-success);">{{ stats.normalDevices }}</div><div class="stat-label">正常设备</div></div>
      <div class="stat-card" style="--accent:#ff3344;"><div class="stat-value" style="color:var(--color-error);">{{ stats.faultDevices }}</div><div class="stat-label">故障设备</div></div>
      <div class="stat-card"><div class="stat-value" style="color:var(--color-primary);">{{ stats.yieldRate }}%</div><div class="stat-label">良品率</div></div>
    </div>

    <!-- Charts -->
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:18px;margin-bottom:24px;">
      <div class="chart-container">
        <h4 class="chart-title">设备状态分布</h4>
        <div style="height:260px;"><canvas ref="statusChartRef"></canvas></div>
      </div>
      <div class="chart-container">
        <h4 class="chart-title">每日测试趋势</h4>
        <div style="height:260px;"><canvas ref="dailyChartRef"></canvas></div>
      </div>
    </div>

    <!-- Operator Stats -->
    <div class="chart-container">
      <h4 class="chart-title">操作员统计</h4>
      <table class="data-table">
        <thead><tr><th>操作员</th><th>测试次数</th><th>通过率</th><th>最近活动</th></tr></thead>
        <tbody>
          <tr v-for="op in operatorStats" :key="op.name">
            <td><span style="color:var(--color-primary);font-weight:600;">{{ op.name }}</span></td>
            <td><code>{{ op.test_count }}</code></td>
            <td>
              <div style="display:flex;align-items:center;gap:8px;">
                <div style="flex:1;height:6px;border-radius:6px;background:var(--color-bg);overflow:hidden;">
                  <div :style="{width:op.pass_rate+'%',height:'100%',borderRadius:'6px',background:op.pass_rate>=90?'var(--color-success)':op.pass_rate>=70?'var(--color-warning)':'var(--color-error)',boxShadow:'0 0 8px '+(op.pass_rate>=90?'var(--color-success)':op.pass_rate>=70?'var(--color-warning)':'var(--color-error)')}"></div>
                </div>
                <span style="font-family:var(--font-mono);font-size:12px;min-width:40px;">{{ op.pass_rate }}%</span>
              </div>
            </td>
            <td style="font-size:12px;">{{ op.last_activity || '--' }}</td>
          </tr>
          <tr v-if="!operatorStats.length"><td colspan="4" class="empty-table">暂无操作员数据</td></tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from 'vue'
import { statsAPI } from '@/api'
import { useUiStore } from '@/stores/ui'
import Chart from 'chart.js/auto'

const uiStore = useUiStore()
const stats = ref({ totalDevices: 0, normalDevices: 0, faultDevices: 0, yieldRate: 0 })
const operatorStats = ref([])
const statusChartRef = ref(null)
const dailyChartRef = ref(null)
let statusChart = null, dailyChart = null

onMounted(async () => {
  try {
    const [overviewRes, opRes, dailyRes] = await Promise.all([
      statsAPI.overview(),
      statsAPI.operators(),
      statsAPI.daily().catch(() => null)
    ])
    const ov = overviewRes.data || overviewRes
    stats.value = {
      totalDevices: ov.total || 0,
      normalDevices: ov.normal || 0,
      faultDevices: ov.fault || 0,
      yieldRate: ov.fault_rate != null ? (100 - ov.fault_rate).toFixed(2) : 100
    }
    operatorStats.value = (opRes.data || opRes || []).map(op => ({
      name: op.operator,
      test_count: op.total,
      pass_rate: op.total > 0 ? Math.round((op.total - op.fault) / op.total * 100) : 0,
      last_activity: '--'
    }))

    await nextTick()
    // device status chart from overview — 互斥分类（从 dispositions 读取）
    if (ov && statusChartRef.value) {
      const dispos = ov.dispositions || {}
      const labels = ['正常', '待返厂', '返厂中', '已返厂', '待处理', '已入库']
      const values = [
        ov.normal || 0,
        dispos['待返厂'] || 0,
        dispos['返厂中'] || 0,
        dispos['已返厂'] || 0,
        dispos['pending'] || 0,
        dispos['stored'] || 0,
      ]
      const bgColorMap = [
        'rgba(0,255,136,0.6)',   // 正常 — green
        'rgba(234,179,8,0.6)',   // 待返厂 — yellow
        'rgba(249,115,22,0.6)',  // 返厂中 — orange
        'rgba(156,163,175,0.6)', // 已返厂 — gray
        'rgba(59,130,246,0.6)',  // 待处理 — blue
        'rgba(99,102,241,0.6)',  // 已入库 — indigo
      ]
      const borderColors = bgColorMap.map(c => c.replace('0.6', '0.9'))
      statusChart = new Chart(statusChartRef.value, {
        type: 'doughnut',
        data: { labels, datasets: [{ data: values, backgroundColor: bgColorMap, borderColor: borderColors, borderWidth: 2 }] },
        options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'right', labels: { color: '#7eb8da', font: { size: 11 } } } } }
      })
    }
    if (dailyRes && dailyChartRef.value) {
      const d = dailyRes.data || dailyRes
      const list = Array.isArray(d) ? d : []
      const labels = list.map(item => item.date)
      const values = list.map(item => item.total)
      if (labels.length > 0) {
        dailyChart = new Chart(dailyChartRef.value, {
          type: 'line',
          data: {
            labels,
            datasets: [{
              label: '测试数', data: values, borderColor: '#00f0ff', backgroundColor: 'rgba(0,240,255,0.08)',
              fill: true, tension: 0.4, pointBackgroundColor: '#00f0ff',
              borderWidth: 2, pointRadius: 3, pointHoverRadius: 6
            }]
          },
          options: {
            responsive: true, maintainAspectRatio: false,
            scales: { x: { ticks: { color: '#7eb8da' }, grid: { color: 'rgba(0,200,255,0.06)' } }, y: { ticks: { color: '#7eb8da' }, grid: { color: 'rgba(0,200,255,0.06)' }, beginAtZero: true } },
            plugins: { legend: { labels: { color: '#7eb8da' } } }
          }
        })
      }
    }
  } catch (e) { console.error(e); uiStore.notify('加载仪表盘数据失败', 'error') }
})
</script>

<style scoped>
.stat-card {
  position: relative;
  overflow: hidden;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: 20px;
  text-align: left;
}
.stat-card::before {
  content: '';
  position: absolute;
  left: 0;
  top: 12%;
  bottom: 12%;
  width: 3px;
  background: var(--color-primary);
  border-radius: 0 3px 3px 0;
  box-shadow: 0 0 10px var(--color-primary);
}
.stat-card .stat-value {
  font-size: 30px;
  font-weight: 800;
  font-family: var(--font-mono);
  padding-left: 14px;
  line-height: 1.2;
}
.stat-card .stat-label {
  font-size: 11px;
  color: var(--color-text-3);
  margin-top: 5px;
  padding-left: 14px;
  text-transform: uppercase;
  letter-spacing: 1.5px;
  font-weight: 600;
}
.chart-container {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: 20px;
  position: relative;
}
.chart-container h4 {
  font-size: 13px;
  font-weight: 700;
  color: var(--color-primary);
  text-transform: uppercase;
  letter-spacing: 1px;
  margin-bottom: 16px;
  padding-bottom: 10px;
  border-bottom: 1px solid var(--color-border);
}
.data-table thead th { background: linear-gradient(180deg, var(--color-surface-2), var(--color-surface)); }
</style>
