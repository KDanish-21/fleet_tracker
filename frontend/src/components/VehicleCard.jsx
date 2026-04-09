import { Truck, Fuel, Gauge, MapPin, Wifi, Satellite, Navigation, Clock, Compass } from 'lucide-react'
import { useFleet } from '../context/FleetContext'

function statusBadge(pos) {
  if (!pos) return <span className="badge-stopped">Offline</span>
  if (pos.alarm && pos.alarm !== 0) return <span className="badge-alarm">Alarm</span>
  if (pos.moving) return <span className="badge-moving">Moving</span>
  return <span className="badge-idle">Stopped</span>
}

function formatTime(unix) {
  if (!unix) return '--'
  const d = new Date(unix * 1000)
  return d.toLocaleString('en-US', { dateStyle: 'short', timeStyle: 'medium', hour12: false })
}

export default function VehicleCard({ vehicle, onClick }) {
  const { selected } = useFleet()
  const pos = vehicle.position
  const isSelected = selected === vehicle.deviceid

  return (
    <div
      onClick={() => onClick(vehicle.deviceid)}
      className={`cursor-pointer rounded-xl border p-4 transition-all duration-150 hover:shadow-md ${
        isSelected
          ? 'border-brand-500 bg-brand-50 shadow-md'
          : 'border-gray-100 bg-white hover:border-gray-200'
      }`}
    >
      {/* Header */}
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-2">
          <div className={`w-9 h-9 rounded-lg flex items-center justify-center ${
            pos?.moving ? 'bg-green-100' : 'bg-gray-100'
          }`}>
            <Truck size={18} className={pos?.moving ? 'text-green-600' : 'text-gray-500'} />
          </div>
          <div>
            <p className="font-semibold text-sm text-gray-900 leading-tight">
              {vehicle.devicename || vehicle.deviceid}
            </p>
            <p className="text-xs text-gray-400">{vehicle.deviceid}</p>
          </div>
        </div>
        {statusBadge(pos)}
      </div>

      {/* Sensors */}
      {pos ? (
        <>
          <div className="grid grid-cols-2 gap-2">
            <Sensor icon={<Gauge size={13} />} label="Speed" value={`${Math.round(pos.speed || 0)} km/h`} />
            <Sensor icon={<Compass size={13} />} label="Course" value={`${pos.course || 0}°`} />
            <Sensor icon={<Fuel size={13} />} label="Fuel" value={`${pos.fuel_l ?? '--'} L`} />
            <Sensor icon={<Navigation size={13} />} label="Distance" value={`${pos.total_distance_km} km`} />
            <Sensor
              icon={<MapPin size={13} />}
              label="Location"
              value={pos.lat ? `${pos.lat.toFixed(4)}, ${pos.lng.toFixed(4)}` : '--'}
            />
            <Sensor icon={<Satellite size={13} />} label="GPS Sats" value={`${pos.gps_sats ?? '--'}`} />
            <Sensor
              icon={<Wifi size={13} />}
              label="GSM Signal"
              value={pos.gsm_signal != null ? `${pos.gsm_signal}` : '--'}
            />
            <Sensor icon={<Clock size={13} />} label="GPS Source" value={pos.gps_source || '--'} />
          </div>

          {/* Device time */}
          <div className="mt-2 flex items-center gap-1 text-xs text-gray-400">
            <Clock size={11} />
            <span>{formatTime(pos.device_time)}</span>
          </div>
        </>
      ) : (
        <p className="text-xs text-gray-400 text-center py-2">No position data</p>
      )}

      {/* Alarm banner */}
      {pos?.alarm_text && (
        <div className="mt-3 bg-red-50 border border-red-100 rounded-lg px-3 py-1.5 text-xs text-red-600 font-medium">
          {pos.alarm_text}
        </div>
      )}
    </div>
  )
}

function Sensor({ icon, label, value }) {
  return (
    <div className="bg-gray-50 rounded-lg px-2.5 py-1.5">
      <div className="flex items-center gap-1 text-gray-400 mb-0.5">
        {icon}
        <span className="text-xs">{label}</span>
      </div>
      <p className="text-sm font-semibold text-gray-800 truncate">{value}</p>
    </div>
  )
}
