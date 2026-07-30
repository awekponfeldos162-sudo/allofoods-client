// functions/jest.config.js
module.exports = {
  testEnvironment: "node",
  setupFiles: ["<rootDir>/test/jest.setup.js"],
  testMatch: ["<rootDir>/test/**/*.test.js"],
  testTimeout: 15000, // les I/O vers l'émulateur Firestore peuvent être lentes à froid
  clearMocks: true,
};
