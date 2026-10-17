import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from './pages/AppShell'
import { Browse } from './pages/Browse'
import { Chat } from './pages/Chat'
import { Donate } from './pages/Donate'
import { Give } from './pages/Give'
import { Impact } from './pages/Impact'
import { Landing } from './pages/Landing'
import { ListingDetail } from './pages/ListingDetail'
import { PickupDetail } from './pages/PickupDetail'
import { Pickups } from './pages/Pickups'
import { SignIn } from './pages/SignIn'
import { TermsPage } from './pages/Terms'
import { AuthProvider } from './services/auth'
import { ChatProvider } from './services/chat'
import { ListingsProvider } from './services/listings'
import { PickupsProvider } from './services/pickups'
import { TermsProvider } from './services/terms'

export default function App() {
  return (
    <AuthProvider>
      <ListingsProvider>
        <PickupsProvider>
          <ChatProvider>
            <TermsProvider>
            <Routes>
              <Route path="/" element={<Landing />} />
              <Route path="/terms" element={<TermsPage />} />
              <Route path="/app/sign-in" element={<SignIn />} />
              <Route path="/app" element={<AppShell />}>
                <Route index element={<Navigate to="/app/browse" replace />} />
                <Route path="browse" element={<Browse />} />
                <Route path="browse/:id" element={<ListingDetail />} />
                <Route path="give" element={<Give />} />
                <Route path="pickups" element={<Pickups />} />
                <Route path="pickups/:itemID" element={<PickupDetail />} />
                <Route path="pickups/:itemID/chat/:requestID" element={<Chat />} />
                <Route path="donate" element={<Donate />} />
                <Route path="impact" element={<Impact />} />
              </Route>
              <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
            </TermsProvider>
          </ChatProvider>
        </PickupsProvider>
      </ListingsProvider>
    </AuthProvider>
  )
}
