import { useState } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import { Map, Truck, BarChart2, Bell, Home, ChevronLeft, ChevronRight, User, LogOut } from 'lucide-react'
import { useFleet } from '../context/FleetContext'

const links = [
  { to: '/',          icon: Home,     label: 'Dashboard'  },
  { to: '/map',       icon: Map,      label: 'Live Map'   },
  { to: '/vehicles',  icon: Truck,    label: 'Vehicles'   },
  { to: '/reports',   icon: BarChart2, label: 'Reports'   },
  { to: '/alarms',    icon: Bell,     label: 'Alarms'     },
]

export default function Sidebar() {
  const { stats } = useFleet()
  const [collapsed, setCollapsed] = useState(false)
  const navigate = useNavigate()

  const token = localStorage.getItem('token')
  const user = (() => {
    try { return JSON.parse(localStorage.getItem('user') || '{}') } catch { return {} }
  })()

  const handleLogout = () => {
    localStorage.removeItem('token')
    localStorage.removeItem('user')
    window.location.href = '/login'
  }

  return (
    <aside className={`${collapsed ? 'w-16' : 'w-56'} bg-brand-900 text-white flex flex-col min-h-screen transition-all duration-200 relative`}>
      {/* Collapse toggle */}
      <button
        onClick={() => setCollapsed(c => !c)}
        className="absolute -right-3 top-6 w-6 h-6 bg-brand-700 rounded-full flex items-center justify-center text-white/80 hover:text-white hover:bg-brand-600 z-10 shadow-md"
      >
        {collapsed ? <ChevronRight size={14} /> : <ChevronLeft size={14} />}
      </button>

      {/* Logo */}
      <div className="px-4 py-5 border-b border-white/10">
        <div className="flex items-center gap-2">
          <Truck className="text-brand-100 flex-shrink-0" size={22} />
          {!collapsed && <span className="font-bold text-lg tracking-tight">FleetTracker</span>}
        </div>
        {!collapsed && <p className="text-xs text-brand-100/60 mt-0.5">GPSPOS Connected</p>}
      </div>

      {/* Stats bar */}
      {!collapsed ? (
        <div className="px-3 py-3 grid grid-cols-2 gap-2 border-b border-white/10">
          <Stat label="Online" value={stats.online} color="text-blue-300" />
          <Stat label="Offline" value={stats.offline} color="text-red-400" />
          <Stat label="Moving" value={stats.moving} color="text-green-400" />
          <Stat label="Stopped" value={stats.stopped} color="text-yellow-400" />
        </div>
      ) : (
        <div className="px-2 py-3 border-b border-white/10 text-center">
          <div className="text-green-400 font-bold text-sm">{stats.online}</div>
          <div className="text-[9px] text-white/40">ON</div>
        </div>
      )}

      {/* Nav */}
      <nav className="flex-1 px-2 py-4 space-y-1">
        {links.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            title={collapsed ? label : undefined}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-brand-600 text-white'
                  : 'text-white/70 hover:bg-white/10 hover:text-white'
              } ${collapsed ? 'justify-center' : ''}`
            }
          >
            <Icon size={18} />
            {!collapsed && label}
            {!collapsed && label === 'Alarms' && stats.alarm > 0 && (
              <span className="ml-auto bg-red-500 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center">
                {stats.alarm}
              </span>
            )}
          </NavLink>
        ))}
      </nav>

      {/* User section */}
      {token && (
        <div className="border-t border-white/10">
          <button
            onClick={() => navigate('/profile')}
            title={collapsed ? user.name || 'Profile' : undefined}
            className={`w-full flex items-center gap-3 px-4 py-3 text-white/70 hover:text-white hover:bg-white/5 transition-colors ${collapsed ? 'justify-center' : ''}`}
          >
            <div className="w-7 h-7 rounded-full bg-brand-600 flex items-center justify-center flex-shrink-0">
              <User size={14} />
            </div>
            {!collapsed && (
              <div className="text-left flex-1 min-w-0">
                <p className="text-xs font-medium truncate">{user.name || 'User'}</p>
                <p className="text-[10px] text-white/40 truncate">{user.email || ''}</p>
              </div>
            )}
          </button>
          {!collapsed && (
            <button
              onClick={handleLogout}
              className="w-full flex items-center gap-3 px-4 py-2 text-red-300/70 hover:text-red-300 hover:bg-white/5 text-xs transition-colors"
            >
              <LogOut size={14} />
              Logout
            </button>
          )}
        </div>
      )}

      {!collapsed && (
        <div className="px-4 py-3 border-t border-white/10 text-[10px] text-white/30">
          Live updates every 10s
        </div>
      )}
    </aside>
  )
}

function Stat({ label, value, color }) {
  return (
    <div className="bg-white/5 rounded-lg px-2 py-1.5 text-center">
      <div className={`font-bold text-lg leading-none ${color}`}>{value}</div>
      <div className="text-white/50 text-xs mt-0.5">{label}</div>
    </div>
  )
}
