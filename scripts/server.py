import subprocess

from flask import Flask, jsonify, render_template_string, request

app = Flask(__name__)

# -------------------------------------------------------------------------------------
# HTML Template
# -------------------------------------------------------------------------------------
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MEGAcmd Dashboard</title>
    <style>
        :root {
            --bg-color: #121212;
            --surface-color: #1e1e1e;
            --primary-color: #d92323;
            --primary-hover: #b01c1c;
            --text-primary: #e0e0e0;
            --text-secondary: #a0a0a0;
            --border-color: #333333;
            --success-color: #2e7d32;
            --error-color: #c62828;
            --input-bg: #2c2c2c;
            --console-bg: #0f0f0f;
            --console-text: #00ff00;
        }

        body {
            font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-primary);
            margin: 0;
            display: flex;
            justify-content: center;
            min-height: 100vh;
        }

        .container {
            width: 100%;
            max-width: 900px;
            margin: 40px 20px;
            background-color: var(--surface-color);
            border-radius: 12px;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5);
            border: 1px solid var(--border-color);
            overflow: hidden;
            display: flex;
            flex-direction: column;
        }

        .header {
            background-color: #181818;
            padding: 20px 30px;
            border-bottom: 1px solid var(--border-color);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .header-title {
            display: flex;
            align-items: center;
            gap: 15px;
            font-size: 1.25rem;
            font-weight: 600;
            color: white;
        }

        .logo {
            width: 36px;
            height: 36px;
            background: linear-gradient(135deg, #d92323, #ff4d4d);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            color: white;
            font-size: 18px;
            box-shadow: 0 2px 10px rgba(217, 35, 35, 0.3);
        }

        .content {
            padding: 30px;
            flex: 1;
        }

        /* Status Indicators */
        .status-badge {
            display: inline-flex;
            align-items: center;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.85rem;
            font-weight: 500;
            gap: 8px;
        }

        .status-badge.online { background-color: rgba(46, 125, 50, 0.2); color: #81c784; border: 1px solid var(--success-color); }
        .status-badge.offline { background-color: rgba(198, 40, 40, 0.2); color: #e57373; border: 1px solid var(--error-color); }

        .pulse {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background-color: currentColor;
            box-shadow: 0 0 8px currentColor;
            animation: pulse-animation 2s infinite;
        }

        @keyframes pulse-animation {
            0% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.5; transform: scale(1.2); }
            100% { opacity: 1; transform: scale(1); }
        }

        /* Forms & Inputs */
        .form-card {
            background-color: #252525;
            padding: 30px;
            border-radius: 8px;
            border: 1px solid var(--border-color);
            max-width: 400px;
            margin: 20px auto;
        }

        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 8px; color: var(--text-secondary); font-size: 0.9rem; }

        input {
            width: 100%;
            padding: 12px;
            background-color: var(--input-bg);
            border: 1px solid var(--border-color);
            border-radius: 6px;
            color: white;
            box-sizing: border-box;
            transition: 0.2s;
        }
        input:focus { border-color: var(--primary-color); outline: none; }

        button {
            width: 100%;
            padding: 12px;
            background-color: var(--primary-color);
            color: white;
            border: none;
            border-radius: 6px;
            font-weight: 600;
            cursor: pointer;
            transition: 0.2s;
        }
        button:hover { background-color: var(--primary-hover); transform: translateY(-1px); }

        .btn-secondary {
            background-color: transparent;
            border: 1px solid var(--border-color);
            color: var(--text-secondary);
            width: auto;
            padding: 8px 16px;
            font-size: 0.9rem;
        }
        .btn-secondary:hover { border-color: var(--text-primary); color: var(--text-primary); transform: none; }

        /* Console Output */
        .console-box {
            background-color: var(--console-bg);
            border: 1px solid var(--border-color);
            border-radius: 6px;
            padding: 15px;
            margin-top: 10px;
            margin-bottom: 25px;
            font-family: 'Consolas', monospace;
            color: var(--console-text);
            font-size: 0.9rem;
            line-height: 1.5;
            white-space: pre-wrap;
            overflow-x: auto;
            min-height: 50px;
            max-height: 400px;
            overflow-y: auto;
        }

        .section-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }
        .section-title { font-size: 0.95rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 1px; font-weight: 600; }
        .last-updated { font-size: 0.8rem; color: #555; }
    </style>
</head>
<body>

    <div class="container">
        <div class="header">
            <div class="header-title">
                <div class="logo">M</div>
                MEGAcmd Manager
            </div>
            {% if logged_in %}
            <form action="/logout" method="post" style="margin:0;">
                <button type="submit" class="btn-secondary">Log Out</button>
            </form>
            {% endif %}
        </div>

        <div class="content">

            <div id="login-view" style="display: {{ 'none' if logged_in else 'block' }};">
                <div class="form-card">
                    <h3 style="margin-top:0; text-align:center;">Connect to Cloud</h3>
                    <p style="text-align:center; color: var(--text-secondary); margin-bottom: 25px;">Enter your MEGA credentials</p>

                    {% if error %}
                    <div style="background: rgba(198,40,40,0.2); color: #ef9a9a; padding: 10px; border-radius: 4px; margin-bottom: 15px; font-size: 0.9rem;">
                        {{ error }}
                    </div>
                    {% endif %}

                    <form action="/login" method="post">
                        <div class="form-group">
                            <label>Email</label>
                            <input type="email" name="email" required>
                        </div>
                        <div class="form-group">
                            <label>Password</label>
                            <input type="password" name="password" required>
                        </div>
                        <div class="form-group">
                            <label>2FA Code (Optional)</label>
                            <input type="text" name="mfa" placeholder="e.g. 123456" inputmode="numeric">
                        </div>
                        <button type="submit">Sign In</button>
                    </form>
                </div>
            </div>

            <div id="dashboard-view" style="display: {{ 'block' if logged_in else 'none' }};">
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 30px;">
                    <div>
                        <div style="font-size:0.9rem; color:var(--text-secondary);">Authenticated User</div>
                        <div style="font-size:1.1rem; font-weight:600;" id="user-email">{{ email }}</div>
                    </div>
                    <div class="status-badge online">
                        <div class="pulse"></div> System Online
                    </div>
                </div>

                <div class="section-header">
                    <div class="section-title">Sync Configuration</div>
                    <div class="last-updated" id="sync-time">Updating...</div>
                </div>
                <div class="console-box" id="sync-output">{{ sync_status }}</div>

                <div class="section-header">
                    <div class="section-title">Active Transfers</div>
                </div>
                <div class="console-box" id="transfers-output">{{ transfers }}</div>
            </div>

        </div>
    </div>

    <script>
        const currentState = {
            loggedIn: {{ 'true' if logged_in else 'false' }}
        };

        function updateDashboard() {
            fetch('/api/status')
                .then(response => response.json())
                .then(data => {
                    // 1. Handle Login State Change
                    if (data.logged_in !== currentState.loggedIn) {
                        // State changed (Logged in <-> Logged out), reload page to swap views cleanly
                        window.location.reload();
                        return;
                    }

                    // 2. Update Content if Logged In
                    if (data.logged_in) {
                        document.getElementById('sync-output').textContent = data.sync_status || "No active syncs found.";
                        document.getElementById('transfers-output').textContent = data.transfers || "No active transfers.";
                        document.getElementById('user-email').textContent = data.email;

                        const now = new Date();
                        document.getElementById('sync-time').textContent = "Updated: " + now.toLocaleTimeString();
                    }
                })
                .catch(err => console.error("Poll failed", err));
        }

        // Poll every 3 seconds
        setInterval(updateDashboard, 3000);
    </script>
</body>
</html>
"""


def get_mega_status():
    try:
        whoami = subprocess.check_output(
            ["mega-whoami"], text=True, stderr=subprocess.STDOUT
        )
        if "Not logged in" in whoami or "Unable to connect" in whoami:
            return False, None

        email = whoami.strip()
        for line in whoami.splitlines():
            if "Account e-mail:" in line:
                email = line.split(":", 1)[1].strip()

        return True, email
    except subprocess.CalledProcessError:
        return False, None


def run_command(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
        return e.output
    except Exception as e:
        return str(e)


# -------------------------------------------------------------------------------------
# ROUTES
# -------------------------------------------------------------------------------------


@app.route("/")
def index():
    logged_in, email = get_mega_status()
    sync_status = "Initializing..."
    transfers = ""

    if logged_in:
        sync_status = run_command(["mega-sync"])
        transfers = run_command(["mega-transfers"])

    return render_template_string(
        HTML_TEMPLATE,
        logged_in=logged_in,
        email=email,
        sync_status=sync_status,
        transfers=transfers,
    )


@app.route("/api/status")
def api_status():
    """JSON Endpoint for JavaScript Polling"""
    logged_in, email = get_mega_status()

    data = {"logged_in": logged_in, "email": email, "sync_status": "", "transfers": ""}

    if logged_in:
        data["sync_status"] = run_command(["mega-sync"])
        data["transfers"] = run_command(["mega-transfers"])

    return jsonify(data)


@app.route("/login", methods=["POST"])
def login():
    email = request.form.get("email")
    password = request.form.get("password")
    mfa = request.form.get("mfa")

    cmd = ["mega-login", email, password]
    if mfa:
        cmd.append(f"--auth-code={mfa}")

    result = run_command(cmd)

    if "Login complete" not in result and "Already logged in" not in result:
        return render_template_string(
            HTML_TEMPLATE, logged_in=False, error=f"Error: {result}"
        )

    return index()


@app.route("/logout", methods=["POST"])
def logout():
    run_command(["mega-logout"])
    return index()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
