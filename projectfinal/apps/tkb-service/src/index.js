const express = require('express');
const app = express();

// Thời khóa biểu mẫu
const schedule = {
  "giangvien": {
    "Thứ 2": [
      { "time": "07:30-09:30", "subject": "Mạng máy tính", "room": "A101", "class": "CNTT01" },
      { "time": "09:45-11:45", "subject": "An ninh mạng", "room": "A102", "class": "CNTT02" }
    ],
    "Thứ 3": [
      { "time": "13:30-15:30", "subject": "Cloud Computing", "room": "B201", "class": "CNTT03" },
      { "time": "15:45-17:45", "subject": "Zero Trust Architecture", "room": "B202", "class": "CNTT04" }
    ],
    "Thứ 4": [
      { "time": "07:30-09:30", "subject": "Kubernetes", "room": "Lab1", "class": "CNTT01" }
    ],
    "Thứ 5": [
      { "time": "09:45-11:45", "subject": "DevSecOps", "room": "Lab2", "class": "CNTT02" }
    ],
    "Thứ 6": [
      { "time": "13:30-15:30", "subject": "Đồ án tốt nghiệp", "room": "A301", "class": "All" }
    ]
  },
  "sinhvien": {
    "Thứ 2": [
      { "time": "07:30-09:30", "subject": "Mạng máy tính", "room": "A101", "teacher": "ThS. Nguyễn Văn A" },
      { "time": "09:45-11:45", "subject": "Lập trình Python", "room": "Lab1", "teacher": "ThS. Trần Thị B" }
    ],
    "Thứ 3": [
      { "time": "13:30-15:30", "subject": "Cơ sở dữ liệu", "room": "A201", "teacher": "TS. Lê Văn C" }
    ],
    "Thứ 4": [
      { "time": "07:30-09:30", "subject": "An ninh mạng", "room": "A102", "teacher": "ThS. Nguyễn Văn A" },
      { "time": "13:30-15:30", "subject": "Thực hành Kubernetes", "room": "Lab2", "teacher": "KS. Phạm Văn D" }
    ],
    "Thứ 5": [
      { "time": "09:45-11:45", "subject": "Cloud Computing", "room": "B201", "teacher": "TS. Hoàng Văn E" }
    ],
    "Thứ 6": [
      { "time": "07:30-09:30", "subject": "Seminar", "room": "A301", "teacher": "All" }
    ]
  }
};

// Middleware để log requests
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} - User: ${req.headers['x-forwarded-user'] || 'anonymous'} - Groups: ${req.headers['x-forwarded-groups'] || 'none'}`);
  next();
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'tkb-service',
    location: 'AWS Singapore',
    node: process.env.HOSTNAME || 'unknown',
    timestamp: new Date().toISOString()
  });
});

// API chính - lấy thời khóa biểu theo role
app.get('/api/tkb', (req, res) => {
  const user = req.headers['x-forwarded-user'] || 'anonymous';
  const groups = req.headers['x-forwarded-groups'] || '';
  
  // Kiểm tra authentication
  if (!user || user === 'anonymous') {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Bạn cần đăng nhập để xem thời khóa biểu',
      service: 'tkb-service',
      location: 'AWS Singapore'
    });
  }

  let role = 'guest';
  let tkb = {};

  if (groups.includes('giangvien')) {
    role = 'giangvien';
    tkb = schedule.giangvien;
  } else if (groups.includes('sinhvien')) {
    role = 'sinhvien';
    tkb = schedule.sinhvien;
  } else {
    return res.status(403).json({
      error: 'Forbidden',
      message: 'Bạn không có quyền xem thời khóa biểu',
      user: user,
      groups: groups,
      service: 'tkb-service',
      location: 'AWS Singapore'
    });
  }

  res.json({
    success: true,
    user: user,
    role: role,
    schedule: tkb,
    metadata: {
      service: 'tkb-service',
      version: '1.0.0',
      location: 'AWS Singapore (ap-southeast-1)',
      node: process.env.HOSTNAME || 'unknown',
      timestamp: new Date().toISOString(),
      message: '🌏 Dữ liệu được xử lý từ AWS Cloud qua WireGuard VPN!'
    }
  });
});

// API lấy TKB theo ngày cụ thể
app.get('/api/tkb/:day', (req, res) => {
  const user = req.headers['x-forwarded-user'] || 'anonymous';
  const groups = req.headers['x-forwarded-groups'] || '';
  const day = req.params.day;

  if (!user || user === 'anonymous') {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  let tkb = {};
  if (groups.includes('giangvien')) {
    tkb = schedule.giangvien[day] || [];
  } else if (groups.includes('sinhvien')) {
    tkb = schedule.sinhvien[day] || [];
  } else {
    return res.status(403).json({ error: 'Forbidden' });
  }

  res.json({
    success: true,
    user: user,
    day: day,
    schedule: tkb,
    metadata: {
      service: 'tkb-service',
      location: 'AWS Singapore'
    }
  });
});

// Info endpoint
app.get('/api/tkb/info', (req, res) => {
  res.json({
    service: 'Thời Khóa Biểu Microservice',
    version: '1.0.0',
    description: 'Microservice quản lý thời khóa biểu - Deployed trên AWS Cloud',
    endpoints: [
      'GET /api/tkb - Lấy toàn bộ TKB theo role',
      'GET /api/tkb/:day - Lấy TKB theo ngày (Thứ 2, Thứ 3, ...)',
      'GET /health - Health check'
    ],
    architecture: {
      deployment: 'AWS Singapore (ap-southeast-1)',
      node: 'aws-worker-1',
      connection: 'WireGuard VPN to OpenStack',
      authentication: 'OAuth2-Proxy + Keycloak (OpenStack)',
      service_mesh: 'Istio'
    }
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔══════════════════════════════════════════════════════════════════╗
║           TKB MICROSERVICE - RUNNING ON AWS                      ║
╠══════════════════════════════════════════════════════════════════╣
║  Port: ${PORT}                                                       ║
║  Location: AWS Singapore (ap-southeast-1)                        ║
║  Node: aws-worker-1                                              ║
║  Connected to: OpenStack via WireGuard VPN                       ║
╚══════════════════════════════════════════════════════════════════╝
  `);
});
