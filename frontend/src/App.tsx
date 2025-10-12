import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { HomePage } from '@/pages/HomePage';
import { StatusPage } from '@/pages/StatusPage';
import './App.css';

function App() {
  return (
    <Router>
      <div className="App">
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/status/:sharingKey" element={<StatusPage />} />
          <Route path="/demo" element={<StatusPage />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
