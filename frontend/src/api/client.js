import axios from 'axios'

const API_BASE = import.meta.env.PROD
  ? 'https://fleet-tracker-5od4.onrender.com/api'
  : '/api'

const LOCALHOST_HOSTS = new Set(['localhost', '127.0.0.1', '0.0.0.0'])

export function normalizeTenantSlug(tenantSlug) {
  return (tenantSlug || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, '')
}

export function getTenantSlug() {
  if (typeof window === 'undefined') return ''

  const host = window.location.hostname.toLowerCase()
  if (host && !LOCALHOST_HOSTS.has(host) && !/^\d+\.\d+\.\d+\.\d+$/.test(host)) {
    const [subdomain] = host.split('.')
    if (subdomain && subdomain !== 'www') return subdomain
  }

  return (
    normalizeTenantSlug(localStorage.getItem('tenantSlug')) ||
    import.meta.env.VITE_TENANT_SLUG ||
    ''
  )
}

const api = axios.create({
  baseURL: API_BASE,
  timeout: 15000,
})

api.interceptors.request.use((config) => {
  const tenantSlug = getTenantSlug()
  if (tenantSlug) {
    config.headers = config.headers || {}
    config.headers['x-tenant-slug'] = tenantSlug
  }
  return config
})

export const setTenantSlug = (tenantSlug) => {
  if (typeof window === 'undefined') return
  const normalized = normalizeTenantSlug(tenantSlug)
  if (normalized) {
    localStorage.setItem('tenantSlug', normalized)
  } else {
    localStorage.removeItem('tenantSlug')
  }
}

// ── Vehicles ──────────────────────────────────────────────
export const getVehicles = () => api.get('/vehicles/')
export const addVehicle  = (data) => api.post('/vehicles/add', data)
export const editVehicle = (data) => api.put('/vehicles/edit', data)

// ── Live Location ─────────────────────────────────────────
export const getLivePositions = (deviceIds = [], lastQueryTime = 0) =>
  api.get('/location/live', {
    params: {
      device_ids: deviceIds,
      last_query_time: lastQueryTime,
    },
  })

export const getSinglePosition = (deviceId) =>
  api.get(`/location/live/${deviceId}`)

// ── Reports ───────────────────────────────────────────────
export const getTrips = (deviceId, beginTime, endTime) =>
  api.post('/reports/trips', { device_id: deviceId, begin_time: beginTime, end_time: endTime })

export const getAlarms = (deviceIds, startDay, endDay) =>
  api.post('/reports/alarms', { device_ids: deviceIds, start_day: startDay, end_day: endDay })

export const getFuelReport = (deviceIds, startDay, endDay) =>
  api.post('/reports/fuel', { device_ids: deviceIds, start_day: startDay, end_day: endDay })

export default api
