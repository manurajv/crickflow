require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const authMiddleware = require('./middleware/auth');
const usersRouter = require('./routes/users');
const teamsRouter = require('./routes/teams');
const matchesRouter = require('./routes/matches');
const tournamentsRouter = require('./routes/tournaments');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());

app.get('/health', (_, res) => {
  res.json({ success: true, service: 'crickflow-api', version: '1.0.0' });
});

app.use('/v1/users', authMiddleware, usersRouter);
app.use('/v1/teams', authMiddleware, teamsRouter);
app.use('/v1/matches', authMiddleware, matchesRouter);
app.use('/v1/tournaments', authMiddleware, tournamentsRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({
    success: false,
    error: { code: err.code || 'INTERNAL_ERROR', message: err.message },
  });
});

app.listen(PORT, () => {
  console.log(`CrickFlow API listening on port ${PORT}`);
});
