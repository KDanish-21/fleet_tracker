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
  const token = localStorage.getItem('token')
  if (token) {
    config.headers = config.headers || {}
    config.headers['Authorization'] = `Bearer ${token}`
  }
  const tenantSlug = getTenantSlug()
  if (tenantSlug) {
    config.headers = config.headers || {}
    config.headers['x-tenant-slug'] = tenantSlug
  }
  return config
})

api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err?.response?.status === 401) {
      localStorage.removeItem('token')
      localStorage.removeItem('user')
      delete api.defaults.headers.common['Authorization']
      if (!window.location.pathname.startsWith('/login')) {
        window.location.href = '/login'
      }
    }
    return Promise.reject(err)
  }
)

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

// ── Tenant Settings (owner) ───────────────────────────────
export const getTenantSettings    = () => api.get('/tenants/settings')
export const updateTenantSettings = (data) => api.put('/tenants/settings', data)
export const deactivateTenant     = () => api.post('/tenants/deactivate')

// ── Users (owner/admin) ───────────────────────────────────
export const getUsers      = () => api.get('/users/')
export const inviteUser    = (data) => api.post('/users/invite', data)
export const updateUserRole = (userId, role) => api.put(`/users/${userId}/role`, { role })
export const deleteUser      = (userId) => api.delete(`/users/${userId}`)
export const updateProfile   = (data)   => api.put('/users/me/profile', data)
export const changePassword  = (data)   => api.post('/users/me/change-password', data)

// ── Tenant Devices (owner/admin) ──────────────────────────
export const getTenantDevices   = () => api.get('/tenants/devices')
export const assignTenantDevice = (deviceId, deviceName = '') =>
  api.post('/tenants/devices', { device_id: deviceId, device_name: deviceName })
export const removeTenantDevice = (deviceId) =>
  api.delete(`/tenants/devices/${encodeURIComponent(deviceId)}`)

// Super Admin
export const getSuperAdminStats = () => api.get('/superadmin/stats')
export const getSuperAdminTenants = () => api.get('/superadmin/tenants')
export const createSuperAdminTenant = (data) => api.post('/superadmin/tenants', data)
export const updateSuperAdminTenant = (tenantId, data) =>
  api.put(`/superadmin/tenants/${encodeURIComponent(tenantId)}`, data)
export const deleteSuperAdminTenant = (tenantId) =>
  api.delete(`/superadmin/tenants/${encodeURIComponent(tenantId)}`)
export const getSuperAdminUsers = () => api.get('/superadmin/users')
export const getSuperAdminTenantUsers = (tenantId) =>
  api.get(`/superadmin/tenants/${encodeURIComponent(tenantId)}/users`)
export const createSuperAdminTenantUser = (tenantId, data) =>
  api.post(`/superadmin/tenants/${encodeURIComponent(tenantId)}/users`, data)
export const updateSuperAdminTenantUserRole = (tenantId, userId, role) =>
  api.put(`/superadmin/tenants/${encodeURIComponent(tenantId)}/users/${encodeURIComponent(userId)}/role`, { role })
export const deleteSuperAdminTenantUser = (tenantId, userId) =>
  api.delete(`/superadmin/tenants/${encodeURIComponent(tenantId)}/users/${encodeURIComponent(userId)}`)
export const getSuperAdminTenantDevices = (tenantId) =>
  api.get(`/superadmin/tenants/${encodeURIComponent(tenantId)}/devices`)

export default api
