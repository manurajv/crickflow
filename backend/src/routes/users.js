const express = require('express');
const router = express.Router();

router.get('/me', (req, res) => {
  res.json({
    success: true,
    data: { uid: req.user.uid, role: req.user.role },
  });
});

module.exports = router;
