const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  const { country, city } = req.query;
  res.json({
    success: true,
    data: [],
    meta: { filters: { country, city } },
  });
});

router.post('/', (req, res) => {
  res.status(201).json({ success: true, data: req.body });
});

module.exports = router;
