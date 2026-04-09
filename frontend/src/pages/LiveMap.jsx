import { useFleet } from '../context/FleetContext'
import MapView from '../components/MapView'
import VehicleCard from '../components/VehicleCard'
import { Search } from 'lucide-react'
import { useState } from 'react'

export default function LiveMap() {
  const { vehicles, setSelected } = useFleet()
  const [search, setSearch] = useState('')

  const filtered = vehicles.filter(v =>
    (v.devicename || v.deviceid).toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="flex h-full gap-0 rounded-xl overflow-hidden border border-gray-100 shadow-sm">
      {/* Left panel */}
      <div className="w-64 bg-white flex flex-col border-r border-gray-100">
        <div className="p-3 border-b border-gray-100">
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search vehicle..."
              value={search}
              onChange={e => setSearch(e.target.value)}
              className="w-full pl-8 pr-3 py-2 text-sm border border-gray-200 rounded-lg outline-none focus:border-brand-500"
            />
          </div>
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-2">
          {filtered.map(v => (
            <VehicleCard
              key={v.deviceid}
              vehicle={v}
              onClick={id => setSelected(id)}
            />
          ))}
          {filtered.length === 0 && (
            <p className="text-center text-gray-400 text-sm py-8">No vehicles match</p>
          )}
        </div>
      </div>

      {/* Map */}
      <div className="flex-1">
        <MapView height="100%" />
      </div>
    </div>
  )
}
