const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({ success: true, data: [] });
});

router.post('/:id/balls', (req, res) => {
  res.json({
    success: true,
    data: { matchId: req.params.id, event: req.body },
  });
});

router.get('/:id/overlay', (req, res) => {
  res.json({ success: true, data: { matchId: req.params.id } });
});

module.exports = router;
