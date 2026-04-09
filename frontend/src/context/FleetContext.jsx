import { createContext, useContext, useState, useEffect, useRef, useCallback } from 'react'
import { getVehicles, getLivePositions } from '../api/client'

const FleetContext = createContext(null)

// If last position was received within 10 minutes, consider online
const ONLINE_THRESHOLD_S = 600

function isOnline(pos) {
  if (!pos || !pos.device_time) return false
  const now = Math.floor(Date.now() / 1000)
  return (now - pos.device_time) < ONLINE_THRESHOLD_S
}

export function FleetProvider({ children }) {
  const [vehicles, setVehicles]       = useState([])
  const [positions, setPositions]     = useState({})
  const [selected, setSelected]       = useState(null)
  const [loading, setLoading]         = useState(true)
  const [error, setError]             = useState(null)
  const lastQueryTime                 = useRef(0)
  const pollInterval                  = useRef(null)

  const fetchVehicles = useCallback(async () => {
    try {
      const res = await getVehicles()
      setVehicles(res.data.vehicles || [])
      setError(null)
    } catch (e) {
      const detail = e?.response?.data?.detail
      setError(detail ? `Failed to load vehicles: ${detail}` : 'Failed to load vehicles')
    }
  }, [])

  const pollPositions = useCallback(async () => {
    try {
      const res = await getLivePositions([], lastQueryTime.current)
      const data = res.data
      if (data.status === 0) {
        lastQueryTime.current = data.lastquerypositiontime || 0
        const updated = {}
        for (const pos of data.positions || []) {
          pos.online = isOnline(pos)
          updated[pos.deviceid] = pos
        }
        setPositions(prev => {
          const merged = { ...prev, ...updated }
          // Re-check online status for all positions
          for (const key in merged) {
            merged[key].online = isOnline(merged[key])
          }
          return merged
        })
      }
    } catch (e) {
      // silent — keep previous positions on poll failure
    }
  }, [])

  useEffect(() => {
    const init = async () => {
      setLoading(true)
      await fetchVehicles()
      await pollPositions()
      setLoading(false)
      pollInterval.current = setInterval(pollPositions, 10000)
    }
    init()
    return () => clearInterval(pollInterval.current)
  }, [fetchVehicles, pollPositions])

  // Derived: enrich vehicles with their live position
  const enrichedVehicles = vehicles.map(v => ({
    ...v,
    position: positions[v.deviceid] || null,
  }))

  const stats = {
    total:   vehicles.length,
    moving:  Object.values(positions).filter(p => p.online && p.moving).length,
    stopped: Object.values(positions).filter(p => p.online && !p.moving).length,
    offline: Object.values(positions).filter(p => !p.online).length + (vehicles.length - Object.keys(positions).length),
    online:  Object.values(positions).filter(p => p.online).length,
    alarm:   Object.values(positions).filter(p => p.alarm && p.alarm !== 0).length,
  }

  return (
    <FleetContext.Provider value={{
      vehicles: enrichedVehicles,
      positions,
      selected,
      setSelected,
      loading,
      error,
      stats,
      refresh: fetchVehicles,
    }}>
      {children}
    </FleetContext.Provider>
  )
}

export const useFleet = () => useContext(FleetContext)
