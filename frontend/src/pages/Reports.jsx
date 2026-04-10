import { useState } from 'react'
import { useFleet } from '../context/FleetContext'
import { getTrips, getFuelReport } from '../api/client'
import { format } from 'date-fns'
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts'
import { Search } from 'lucide-react'

const tabs = ['Trips', 'Fuel']

export default function Reports() {
  const { vehicles } = useFleet()
  const [tab, setTab]           = useState('Trips')
  const [deviceId, setDeviceId] = useState('')
  const [startDate, setStart]   = useState(format(new Date(), 'yyyy-MM-dd'))
  const [endDate, setEnd]       = useState(format(new Date(), 'yyyy-MM-dd'))
  const [data, setData]         = useState(null)
  const [loading, setLoading]   = useState(false)
  const [error, setError]       = useState(null)

  const handleFetch = async () => {
    if (!deviceId) { setError('Please select a vehicle'); return }
    setLoading(true); setError(null); setData(null)
    try {
      if (tab === 'Trips') {
        const res = await getTrips(deviceId, `${startDate} 00:00:00`, `${endDate} 23:59:59`)
        setData(res.data)
      } else {
        const res = await getFuelReport([deviceId], startDate, endDate)
        setData(res.data)
      }
    } catch (e) {
      setError(e.response?.data?.detail || 'Failed to fetch report')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="space-y-5">
      <h1 className="text-xl font-bold text-gray-900">Reports</h1>

      {/* Tabs */}
      <div className="flex gap-2 border-b border-gray-200">
        {tabs.map(t => (
          <button
            key={t}
            onClick={() => { setTab(t); setData(null) }}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
              tab === t ? 'border-brand-500 text-brand-600' : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      {/* Filters */}
      <div className="card flex items-end gap-4 flex-wrap">
        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">Vehicle</label>
          <select
            value={deviceId}
            onChange={e => setDeviceId(e.target.value)}
            className="input min-w-48"
          >
            <option value="">Select vehicle...</option>
            {vehicles.map(v => (
              <option key={v.deviceid} value={v.deviceid}>
                {v.devicename || v.deviceid}
              </option>
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
          {loading ? 'Loading...' : 'Generate Report'}
        </button>
      </div>

      {error && <div className="bg-red-50 text-red-600 px-4 py-3 rounded-lg text-sm">{error}</div>}

      {/* Trip Results */}
      {tab === 'Trips' && data && <TripResults data={data} />}

      {/* Fuel Results */}
      {tab === 'Fuel' && data && <FuelResults data={data} />}
    </div>
  )
}

function TripResults({ data }) {
  const trips = data.totaltrips || []

  if (trips.length === 0) {
    return (
      <div className="card text-center py-12">
        <p className="text-gray-500 font-medium">No trips found for the selected period</p>
      </div>
    )
  }

  const chartData = trips.map((t, i) => ({
    name: `Trip ${i + 1}`,
    distance: Math.round((t.tripdistance || 0) / 1000),
    maxSpeed: Math.round(t.maxspeed || 0),
  }))

  const formatTripTime = (ts) => {
    if (!ts) return '--'
    try { return format(new Date(ts), 'dd MMM HH:mm') } catch { return '--' }
  }

  return (
    <div className="space-y-4">
      {/* Summary */}
      <div className="grid grid-cols-4 gap-4">
        {[
          { label: 'Total Trips',    value: data.total || trips.length },
          { label: 'Total Distance', value: `${Math.round((data.totaldistance || 0) / 1000)} km` },
          { label: 'Max Speed',      value: `${Math.round(data.totalmaxspeed || 0)} km/h` },
          { label: 'Avg Speed',      value: `${Math.round(data.totalaveragespeed || 0)} km/h` },
        ].map(s => (
          <div key={s.label} className="card text-center">
            <p className="text-2xl font-bold text-brand-600">{s.value}</p>
            <p className="text-xs text-gray-500 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Chart */}
      {chartData.length > 0 && (
        <div className="card">
          <h3 className="font-semibold text-gray-700 mb-4">Distance per Trip (km)</h3>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="name" tick={{ fontSize: 11 }} />
              <YAxis tick={{ fontSize: 11 }} />
              <Tooltip />
              <Bar dataKey="distance" fill="#6366f1" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Trip table */}
      <div className="card p-0 overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50 border-b border-gray-100">
              {['#', 'Start Time', 'End Time', 'Distance', 'Max Speed', 'Avg Speed', 'Park Time'].map(h => (
                <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {trips.map((t, i) => (
              <tr key={i} className="border-b border-gray-50 hover:bg-gray-50">
                <td className="px-4 py-3 text-gray-500">{i + 1}</td>
                <td className="px-4 py-3">{formatTripTime(t.starttime)}</td>
                <td className="px-4 py-3">{formatTripTime(t.endtime)}</td>
                <td className="px-4 py-3 font-medium">{Math.round((t.tripdistance || 0) / 1000)} km</td>
                <td className="px-4 py-3">{Math.round(t.maxspeed || 0)} km/h</td>
                <td className="px-4 py-3">{Math.round(t.averagespeed || 0)} km/h</td>
                <td className="px-4 py-3 text-gray-500">{Math.round((t.parktime || 0) / 60000)} min</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function FuelResults({ data }) {
  const records = data.records || []

  if (records.length === 0) {
    return (
      <div className="card text-center py-12">
        <p className="text-gray-500 font-medium">No fuel data found for the selected period</p>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {records.map((r, i) => (
        <div key={i} className="card">
          <h3 className="font-semibold text-gray-800 mb-3">{r.deviceid}</h3>
          <div className="grid grid-cols-4 gap-4">
            {[
              { label: 'Avg L/100km',  value: r.avgoilper100km != null ? `${r.avgoilper100km} L` : '--' },
              { label: 'Avg L/hr',     value: r.avgoilperhour != null ? `${r.avgoilperhour} L` : '--' },
              { label: 'Total Fuel',   value: `${((r.currenttotalil || 0) / 100).toFixed(1)} L` },
              { label: 'Idle Fuel',    value: `${((r.totalidleoil || 0) / 100).toFixed(1)} L` },
            ].map(s => (
              <div key={s.label} className="bg-gray-50 rounded-lg p-3 text-center">
                <p className="text-lg font-bold text-brand-600">{s.value}</p>
                <p className="text-xs text-gray-500 mt-0.5">{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}
