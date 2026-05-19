const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({ success: true, data: [] });
});

router.get('/:id/standings', (req, res) => {
  res.json({ success: true, data: { tournamentId: req.params.id, standings: [] } });
});

module.exports = router;
