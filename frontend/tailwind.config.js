/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#111111",
        line: "#e7e7e7",
        muted: "#6f6f6f"
      }
    }
  },
  plugins: []
};

