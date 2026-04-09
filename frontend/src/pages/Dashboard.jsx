import { useFleet } from '../context/FleetContext'
import { useNavigate } from 'react-router-dom'
import { Truck, TrendingUp, AlertTriangle, Activity, Wifi, WifiOff } from 'lucide-react'
import { PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts'

const STATUS_COLORS = {
  Moving: '#22c55e',
  Stopped: '#f59e0b',
  Offline: '#ef4444',
  Online: '#3b82f6',
  Alarm: '#dc2626',
}

function formatTime(unix) {
  if (!unix) return '--'
  const d = new Date(unix * 1000)
  return d.toLocaleString('en-US', { dateStyle: 'short', timeStyle: 'short', hour12: false })
}

export default function Dashboard() {
  const { vehicles, stats, loading, error } = useFleet()
  const navigate = useNavigate()

  if (loading) return <LoadingScreen />
  if (error) return <ErrorScreen message={error} />

  // Status pie chart
  const statusPie = [
    { name: 'Moving', value: stats.moving, color: STATUS_COLORS.Moving },
    { name: 'Stopped', value: stats.stopped, color: STATUS_COLORS.Stopped },
    { name: 'Alarm', value: stats.alarm, color: STATUS_COLORS.Alarm },
  ].filter(d => d.value > 0)

  // Online/Offline pie chart
  const connectionPie = [
    { name: 'Online', value: stats.online, color: STATUS_COLORS.Online },
    { name: 'Offline', value: stats.offline, color: STATUS_COLORS.Offline },
  ].filter(d => d.value > 0)

  // Speed bar chart
  const speedData = vehicles
    .filter(v => v.position)
    .map(v => ({
      name: v.devicename || v.deviceid,
      speed: Math.round(v.position.speed || 0),
      status: v.position.online ? (v.position.moving ? 'Moving' : 'Stopped') : 'Offline',
    }))
    .sort((a, b) => b.speed - a.speed)

  // Top movers
  const topMovers = vehicles
    .filter(v => v.position?.online && v.position?.moving)
    .sort((a, b) => (b.position?.speed || 0) - (a.position?.speed || 0))
    .slice(0, 5)

  return (
    <div className="space-y-5 pb-6">
      {/* Stat cards */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
        <StatCard icon={<Truck size={22} />} label="Total" value={stats.total} color="indigo" onClick={() => navigate('/vehicles')} />
        <StatCard icon={<Wifi size={22} />} label="Online" value={stats.online} color="blue" />
        <StatCard icon={<Activity size={22} />} label="Moving" value={stats.moving} color="green" onClick={() => navigate('/map')} />
        <StatCard icon={<TrendingUp size={22} />} label="Stopped" value={stats.stopped} color="amber" />
        <StatCard icon={<WifiOff size={22} />} label="Offline" value={stats.offline} color="red" />
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {/* Status pie */}
        <div className="card">
          <h2 className="font-semibold text-gray-800 text-sm mb-3">Vehicle Status</h2>
          <div className="h-48">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie data={statusPie} cx="50%" cy="50%" innerRadius={45} outerRadius={75} dataKey="value" label={({ name, value }) => `${name}: ${value}`} labelLine={false}>
                  {statusPie.map((e, i) => <Cell key={i} fill={e.color} />)}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div className="flex justify-center gap-4 mt-1">
            {statusPie.map(d => (
              <div key={d.name} className="flex items-center gap-1.5 text-xs text-gray-600">
                <span className="w-2.5 h-2.5 rounded-full" style={{ background: d.color }} />
                {d.name} ({d.value})
              </div>
            ))}
          </div>
        </div>

        {/* Connection pie */}
        <div className="card">
          <h2 className="font-semibold text-gray-800 text-sm mb-3">Connection Status</h2>
          <div className="h-48">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie data={connectionPie} cx="50%" cy="50%" innerRadius={45} outerRadius={75} dataKey="value" label={({ name, value }) => `${name}: ${value}`} labelLine={false}>
                  {connectionPie.map((e, i) => <Cell key={i} fill={e.color} />)}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div className="flex justify-center gap-4 mt-1">
            {connectionPie.map(d => (
              <div key={d.name} className="flex items-center gap-1.5 text-xs text-gray-600">
                <span className="w-2.5 h-2.5 rounded-full" style={{ background: d.color }} />
                {d.name} ({d.value})
              </div>
            ))}
          </div>
        </div>

        {/* Speed bar chart */}
        <div className="card">
          <h2 className="font-semibold text-gray-800 text-sm mb-3">Speed (km/h)</h2>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={speedData} layout="vertical" margin={{ left: 0, right: 10 }}>
                <XAxis type="number" tick={{ fontSize: 10 }} />
                <YAxis type="category" dataKey="name" width={90} tick={{ fontSize: 10 }} />
                <Tooltip contentStyle={{ fontSize: 12 }} formatter={(val) => [`${val} km/h`, 'Speed']} />
                <Bar dataKey="speed" radius={[0, 4, 4, 0]} barSize={16}>
                  {speedData.map((entry, i) => (
                    <Cell key={i} fill={entry.status === 'Moving' ? '#22c55e' : entry.status === 'Stopped' ? '#f59e0b' : '#94a3b8'} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Vehicle lists */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {/* Top movers */}
        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-semibold text-gray-800 text-sm">Top Moving Vehicles</h2>
            <button className="text-xs text-brand-600 hover:text-brand-700 font-medium" onClick={() => navigate('/map')}>View on Map →</button>
          </div>
          {topMovers.length === 0 ? (
            <p className="text-center text-gray-400 text-sm py-8">No vehicles moving</p>
          ) : (
            <div className="space-y-2">
              {topMovers.map(v => (
                <div key={v.deviceid} onClick={() => navigate('/map')} className="flex items-center justify-between p-3 rounded-lg bg-gray-50 hover:bg-green-50 cursor-pointer transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-lg bg-green-100 flex items-center justify-center">
                      <Truck size={16} className="text-green-600" />
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-gray-900">{v.devicename || v.deviceid}</p>
                      <p className="text-xs text-gray-400">{v.deviceid}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-bold text-green-600">{Math.round(v.position.speed)} km/h</p>
                    <p className="text-xs text-gray-400">{v.position.total_distance_km} km</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* All vehicles */}
        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-semibold text-gray-800 text-sm">All Vehicles</h2>
            <span className="text-xs text-gray-400">{vehicles.length} total</span>
          </div>
          <div className="space-y-2 max-h-80 overflow-y-auto pr-1">
            {vehicles.map(v => {
              const pos = v.position
              const online = pos?.online
              const moving = online && pos?.moving
              return (
                <div key={v.deviceid} onClick={() => navigate('/map')} className="flex items-center justify-between p-2.5 rounded-lg hover:bg-gray-50 cursor-pointer transition-colors border border-gray-100">
                  <div className="flex items-center gap-2.5">
                    <div className={`w-2 h-2 rounded-full ${moving ? 'bg-green-500' : online ? 'bg-yellow-400' : 'bg-red-400'}`} />
                    <div>
                      <p className="text-sm font-medium text-gray-800">{v.devicename || v.deviceid}</p>
                      <div className="flex items-center gap-2 text-xs text-gray-400">
                        {online ? <span>{Math.round(pos.speed || 0)} km/h</span> : <span className="text-red-400">Offline</span>}
                        <span>·</span>
                        <span>{pos ? formatTime(pos.device_time) : '--'}</span>
                      </div>
                    </div>
                  </div>
                  <div>
                    {!online ? <span className="badge-stopped text-[10px]">Offline</span>
                      : pos?.alarm ? <span className="badge-alarm text-[10px]">Alarm</span>
                      : moving ? <span className="badge-moving text-[10px]">Moving</span>
                      : <span className="badge-idle text-[10px]">Stopped</span>}
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}

function StatCard({ icon, label, value, color, onClick }) {
  const styles = {
    indigo: 'bg-indigo-50 text-indigo-600',
    blue: 'bg-blue-50 text-blue-600',
    green: 'bg-green-50 text-green-600',
    amber: 'bg-amber-50 text-amber-600',
    red: 'bg-red-50 text-red-600',
  }
  return (
    <div onClick={onClick} className={`card flex items-center gap-3 ${onClick ? 'cursor-pointer hover:shadow-md transition-shadow' : ''}`}>
      <div className={`w-11 h-11 rounded-xl flex items-center justify-center ${styles[color]}`}>{icon}</div>
      <div>
        <p className="text-2xl font-bold text-gray-900">{value}</p>
        <p className="text-xs text-gray-500 font-medium">{label}</p>
      </div>
    </div>
  )
}

function LoadingScreen() {
  return (
    <div className="flex items-center justify-center h-full">
      <div className="text-center">
        <div className="w-10 h-10 border-4 border-brand-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
        <p className="text-gray-500 text-sm">Connecting to GPSPOS...</p>
      </div>
    </div>
  )
}

function ErrorScreen({ message }) {
  return (
    <div className="flex items-center justify-center h-full">
      <div className="text-center text-red-500">
        <AlertTriangle size={40} className="mx-auto mb-2" />
        <p className="font-semibold">{message}</p>
      </div>
    </div>
  )
}
