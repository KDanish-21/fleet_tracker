import { useEffect, useRef } from 'react'
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet'
import L from 'leaflet'
import { useFleet } from '../context/FleetContext'
import { Truck, Gauge, Fuel, Navigation, Compass, Satellite, Signal, Clock, AlertTriangle, Thermometer } from 'lucide-react'

const DEFAULT_CENTER = [-6.7924, 39.2083] // Dar es Salaam
const DEFAULT_ZOOM = 11

// Create colored circle marker icons
function createIcon(color, scale = 1) {
  const size = Math.round(24 * scale)
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 24 24">
      <circle cx="12" cy="12" r="10" fill="${color}" stroke="#fff" stroke-width="2"/>
      <circle cx="12" cy="12" r="4" fill="#fff"/>
    </svg>`
  return L.divIcon({
    html: svg,
    className: '',
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
    popupAnchor: [0, -size / 2],
  })
}

function formatTime(unix) {
  if (!unix) return '--'
  const d = new Date(unix * 1000)
  return d.toLocaleString('en-US', { dateStyle: 'short', timeStyle: 'medium', hour12: false })
}

// Component to fly map to selected vehicle
function MapUpdater({ center }) {
  const map = useMap()
  const prevCenter = useRef(center)

  useEffect(() => {
    if (
      center &&
      (center[0] !== prevCenter.current[0] || center[1] !== prevCenter.current[1])
    ) {
      map.flyTo(center, map.getZoom(), { duration: 0.8 })
      prevCenter.current = center
    }
  }, [center, map])

  return null
}

export default function MapView({ height = '100%' }) {
  const { vehicles, selected, setSelected } = useFleet()

  const vehiclesWithPos = vehicles.filter(v => v.position?.lat && v.position?.lng)

  // Auto-center on selected vehicle
  const mapCenter = (() => {
    if (selected) {
      const v = vehiclesWithPos.find(v => v.deviceid === selected)
      if (v?.position) return [v.position.lat, v.position.lng]
    }
    if (vehiclesWithPos.length > 0) {
      return [vehiclesWithPos[0].position.lat, vehiclesWithPos[0].position.lng]
    }
    return DEFAULT_CENTER
  })()

  return (
    <div style={{ height }} className="w-full rounded-xl overflow-hidden">
      <MapContainer
        center={mapCenter}
        zoom={DEFAULT_ZOOM}
        style={{ height: '100%', width: '100%' }}
        scrollWheelZoom={true}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://tile.openstreetmap.de/{z}/{x}/{y}.png"
        />
        <MapUpdater center={mapCenter} />

        {vehiclesWithPos.map(vehicle => {
          const pos = vehicle.position
          const isMoving = pos.moving
          const hasAlarm = pos.alarm && pos.alarm !== 0
          const isSelected = vehicle.deviceid === selected

          const color = hasAlarm ? '#ef4444' : isMoving ? '#22c55e' : '#f59e0b'
          const icon = createIcon(color, isSelected ? 1.4 : 1.1)

          return (
            <Marker
              key={vehicle.deviceid}
              position={[pos.lat, pos.lng]}
              icon={icon}
              eventHandlers={{
                click: () => setSelected(vehicle.deviceid),
              }}
            >
              <Popup maxWidth={320}>
                <div className="min-w-56">
                  <p className="font-bold text-gray-900 text-sm mb-1 flex items-center gap-1">
                    <Truck size={14} />
                    {vehicle.devicename || vehicle.deviceid}
                  </p>
                  <p className="text-xs text-gray-400 mb-2">ID: {vehicle.deviceid}</p>

                  <div className="grid grid-cols-2 gap-x-4 gap-y-0.5">
                    <InfoRow icon={<Gauge size={12} />} label="Speed" value={`${Math.round(pos.speed || 0)} km/h`} />
                    <InfoRow icon={<Compass size={12} />} label="Course" value={`${pos.course || 0}°`} />
                    <InfoRow icon={<Navigation size={12} />} label="Distance" value={`${pos.total_distance_km} km`} />
                    <InfoRow icon={<Fuel size={12} />} label="Fuel" value={`${pos.fuel_l ?? '--'} L`} />
                    <InfoRow icon={<Satellite size={12} />} label="GPS Sats" value={`${pos.gps_sats ?? '--'}`} />
                    <InfoRow icon={<Signal size={12} />} label="GSM" value={`${pos.gsm_signal ?? '--'}`} />
                    <InfoRow icon={<Thermometer size={12} />} label="Temp" value={pos.temp1 ? `${pos.temp1}°C` : '--'} />
                    <InfoRow icon={<Navigation size={12} />} label="Source" value={pos.gps_source || '--'} />
                  </div>

                  <div className="mt-2 pt-2 border-t border-gray-100">
                    <InfoRow icon={<Clock size={12} />} label="Device Time" value={formatTime(pos.device_time)} />
                    <InfoRow icon={<Navigation size={12} />} label="Coordinates" value={`${pos.lat.toFixed(5)}, ${pos.lng.toFixed(5)}`} />
                    <InfoRow icon={<Gauge size={12} />} label="Status" value={pos.moving ? 'Moving' : 'Stopped'} />
                  </div>

                  {pos.alarm_text && (
                    <div className="mt-2 text-xs text-red-600 font-medium bg-red-50 px-2 py-1 rounded flex items-center gap-1">
                      <AlertTriangle size={12} />
                      {pos.alarm_text}
                    </div>
                  )}
                </div>
              </Popup>
            </Marker>
          )
        })}
      </MapContainer>
    </div>
  )
}

function InfoRow({ icon, label, value }) {
  return (
    <div className="flex items-center gap-1.5 text-xs text-gray-600 mb-1">
      <span className="text-gray-400">{icon}</span>
      <span className="text-gray-500">{label}:</span>
      <span className="font-medium text-gray-800">{value}</span>
    </div>
  )
}
