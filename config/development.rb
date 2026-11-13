export(
  storage: {
    noteflakes_com: {
      path: ENV['DATABASE_PATH'] || 'noteflakes.com/storage/development.db'
    }
  }
)
