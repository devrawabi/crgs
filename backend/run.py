import os

from dotenv import load_dotenv

load_dotenv()

from app import create_app

app = create_app()

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5318))
    debug = (
        os.getenv("FLASK_ENV", "production") == "development"
        and os.getenv("FLASK_DEBUG", "0").lower() in ("1", "true", "yes")
    )
    if debug:
        app.run(host="0.0.0.0", port=port, debug=True, use_reloader=False)
    else:
        from waitress import serve

        serve(app, host="0.0.0.0", port=port, threads=8)
