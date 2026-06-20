// EasyCall Configuration
// Copy this to .env and fill in your values
module.exports = {
  PORT: process.env.PORT || 3000,
  JWT_SECRET: process.env.JWT_SECRET || 'easycall_secret_key_change_in_production',
  STUN_SERVERS: [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302'
  ],
  TURN_SERVERS: process.env.TURN_SERVERS ? JSON.parse(process.env.TURN_SERVERS) : []
};
