import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './context/AuthContext'
import { FleetProvider } from './context/FleetContext'
import Sidebar from './components/Sidebar'
import Dashboard from './pages/Dashboard'
import LiveMap from './pages/LiveMap'
import Vehicles from './pages/Vehicles'
import Reports from './pages/Reports'
import Alarms from './pages/Alarms'
import Profile from './pages/Profile'
import TenantDevices from './pages/TenantDevices'
import TenantUsers from './pages/TenantUsers'
import TenantSettings from './pages/TenantSettings'
import SuperAdmin from './pages/SuperAdmin'
import Login from './pages/Login'
import Register from './pages/Register'

function ProtectedRoute({ children }) {
  const { isAuthenticated, loading } = useAuth()
  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-gray-50">
        <div className="w-10 h-10 border-4 border-brand-500 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }
  return isAuthenticated ? children : <Navigate to="/login" replace />
}

function AppLayout() {
  return (
    <FleetProvider>
      <div className="flex h-screen overflow-hidden bg-gray-50">
        <Sidebar />
        <main className="flex-1 overflow-y-auto p-6">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/map" element={<LiveMap />} />
            <Route path="/vehicles" element={<Vehicles />} />
            <Route path="/reports" element={<Reports />} />
            <Route path="/alarms" element={<Alarms />} />
            <Route path="/profile" element={<Profile />} />
            <Route path="/admin/devices" element={<TenantDevices />} />
            <Route path="/admin/users" element={<TenantUsers />} />
            <Route path="/admin/settings" element={<TenantSettings />} />
            <Route path="/superadmin" element={<SuperAdmin />} />
          </Routes>
        </main>
      </div>
    </FleetProvider>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route path="/*" element={
            <ProtectedRoute>
              <AppLayout />
            </ProtectedRoute>
          } />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}
