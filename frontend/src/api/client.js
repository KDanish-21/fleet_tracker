import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
  timeout: 15000,
})

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
