import { useState } from 'react'
import { useFleet } from '../context/FleetContext'
import { getAlarms } from '../api/client'
import { format } from 'date-fns'
import { AlertTriangle, Search, CheckCircle } from 'lucide-react'

function formatUnixTime(unix) {
  if (!unix) return '--'
  const d = new Date(Number(unix) * 1000)
  return d.toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'medium', hour12: false })
}

export default function Alarms() {
  const { vehicles } = useFleet()
  const [deviceId, setDeviceId] = useState('')
  const [startDate, setStart]   = useState(format(new Date(), 'yyyy-MM-dd'))
  const [endDate, setEnd]       = useState(format(new Date(), 'yyyy-MM-dd'))
  const [alarms, setAlarms]     = useState([])
  const [loading, setLoading]   = useState(false)
  const [error, setError]       = useState(null)
  const [fetched, setFetched]   = useState(false)

  const handleFetch = async () => {
    const ids = deviceId ? [deviceId] : vehicles.map(v => v.deviceid)
    if (ids.length === 0) { setError('No vehicles available'); return }
    setLoading(true); setError(null)
    try {
      const res = await getAlarms(ids, startDate, endDate)
      setAlarms(res.data.records || [])
      setFetched(true)
    } catch (e) {
      setError(e.response?.data?.detail || 'Failed to fetch alarms')
    } finally {
      setLoading(false)
    }
  }

  const alarmColor = (state) => {
    const n = Number(state)
    if (n & 0x01) return 'border-l-red-500 bg-red-50'      // SOS
    if (n & 0x20) return 'border-l-orange-400 bg-orange-50' // Overspeed
    if (n & 0x10) return 'border-l-purple-400 bg-purple-50' // Geofence
    if (n & 0x80) return 'border-l-yellow-400 bg-yellow-50' // Fuel theft
    if (n & 0x04) return 'border-l-red-400 bg-red-50'       // Power cut
    return 'border-l-gray-300 bg-gray-50'
  }

  const alarmLabel = (state) => {
    const n = Number(state)
    const labels = []
    if (n & 0x01) labels.push('SOS')
    if (n & 0x02) labels.push('Low Battery')
    if (n & 0x04) labels.push('Power Cut')
    if (n & 0x08) labels.push('Vibration')
    if (n & 0x10) labels.push('Geofence')
    if (n & 0x20) labels.push('Overspeed')
    if (n & 0x40) labels.push('Movement')
    if (n & 0x80) labels.push('Fuel Theft')
    return labels.length ? labels.join(', ') : 'Alarm'
  }

  const getVehicleName = (did) => {
    const v = vehicles.find(v => v.deviceid === did)
    return v?.devicename || did
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-gray-900">Alarms</h1>
        {fetched && <span className="text-sm text-gray-500">{alarms.length} alarm(s) found</span>}
      </div>

      {/* Filters */}
      <div className="card flex items-end gap-4 flex-wrap">
        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">Vehicle (optional)</label>
          <select value={deviceId} onChange={e => setDeviceId(e.target.value)} className="input min-w-48">
            <option value="">All vehicles</option>
            {vehicles.map(v => (
              <option key={v.deviceid} value={v.deviceid}>{v.devicename || v.deviceid}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">Start Date</label>
          <input type="date" value={startDate} onChange={e => setStart(e.target.value)} className="input" />
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">End Date</label>
          <input type="date" value={endDate} onChange={e => setEnd(e.target.value)} className="input" />
        </div>
        <button className="btn-primary flex items-center gap-2" onClick={handleFetch} disabled={loading}>
          <Search size={15} />
          {loading ? 'Loading...' : 'Fetch Alarms'}
        </button>
      </div>

      {error && <div className="bg-red-50 text-red-600 px-4 py-3 rounded-lg text-sm">{error}</div>}

      {fetched && alarms.length === 0 && (
        <div className="card text-center py-12">
          <CheckCircle size={40} className="mx-auto text-green-400 mb-2" />
          <p className="text-gray-500 font-medium">No alarms in this period</p>
        </div>
      )}

      {/* Alarm list */}
      <div className="space-y-2">
        {alarms.map((a, i) => (
          <div key={i} className={`rounded-xl border-l-4 px-4 py-3 ${alarmColor(a.nAlarmState)}`}>
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-2">
                <AlertTriangle size={16} className="text-orange-500 mt-0.5" />
                <div>
                  <p className="font-semibold text-sm text-gray-900">{alarmLabel(a.nAlarmState)}</p>
                  <p className="text-xs text-gray-500 mt-0.5">
                    {getVehicleName(a.deviceid || a.strTEID)} &bull; ID: {a.deviceid || a.strTEID}
                  </p>
                </div>
              </div>
              <div className="text-right text-xs text-gray-500">
                <p>{formatUnixTime(a.nTime)}</p>
              </div>
            </div>
            <div className="mt-2 grid grid-cols-4 gap-2 text-xs text-gray-600">
              <span>Speed: {a.nSpeed || 0} km/h</span>
              <span>Lat: {Number(a.dbLat)?.toFixed(4) ?? '--'}</span>
              <span>Lon: {Number(a.dbLon)?.toFixed(4) ?? '--'}</span>
              <span>GSM: {a.nGSMSignal || '--'}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
