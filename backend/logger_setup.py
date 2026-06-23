# logger_setup.py (or paste at top of app.py)
import os
import sys
import logging
from logging.handlers import RotatingFileHandler
import io
import contextlib
import traceback
import functools
from typing import Callable, Any, Coroutine

LOG_DIR = "logs"
os.makedirs(LOG_DIR, exist_ok=True)

def create_logger(name: str, filename: str, level=logging.INFO) -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(level)
    # Avoid duplicate handlers on reload
    if logger.handlers:
        return logger

    log_path = os.path.join(LOG_DIR, filename)
    handler = RotatingFileHandler(log_path, maxBytes=5 * 1024 * 1024, backupCount=5)
    formatter = logging.Formatter("%(asctime)s [%(name)s] %(levelname)s: %(message)s",
                                  datefmt="%Y-%m-%d %H:%M:%S")
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    # Also mirror to console (optional)
    console = logging.StreamHandler(sys.__stdout__)
    console.setFormatter(formatter)
    logger.addHandler(console)

    return logger

# endpoint loggers
mealplan_logger = create_logger("MEALPLAN", "mealplan.log")
workoutplan_logger = create_logger("WORKOUTPLAN", "workoutplan.log")
user_logger = create_logger("USER", "user.log")
error_logger = create_logger("ERROR", "errors.log", level=logging.ERROR)

# --------------------
# Decorator to capture prints within an endpoint
# --------------------
def capture_endpoint_logs(logger: logging.Logger):
    """
    Decorator to capture print() calls and any stdout/stderr output inside the decorated endpoint.
    Works with both async and sync view functions.
    Logs captured text to the provided logger under INFO.
    Also logs exceptions to error_logger and re-raises them.
    """
    def decorator(func: Callable):
        if asyncio.iscoroutinefunction(func):
            @functools.wraps(func)
            async def async_wrapper(*args, **kwargs):
                buf = io.StringIO()
                try:
                    # redirect both stdout and stderr to the buffer for the duration
                    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
                        result = await func(*args, **kwargs)
                except Exception:
                    # capture buffer + exception trace
                    out = buf.getvalue()
                    if out:
                        logger.info("Captured output:\n%s", out)
                    error_logger.exception("Unhandled exception in %s", func.__name__)
                    raise
                else:
                    out = buf.getvalue()
                    if out:
                        # log captured prints at INFO level
                        logger.info("Captured output:\n%s", out)
                    return result
            return async_wrapper
        else:
            @functools.wraps(func)
            def sync_wrapper(*args, **kwargs):
                buf = io.StringIO()
                try:
                    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
                        result = func(*args, **kwargs)
                except Exception:
                    out = buf.getvalue()
                    if out:
                        logger.info("Captured output:\n%s", out)
                    error_logger.exception("Unhandled exception in %s", func.__name__)
                    raise
                else:
                    out = buf.getvalue()
                    if out:
                        logger.info("Captured output:\n%s", out)
                    return result
            return sync_wrapper
    return decorator

# make asyncio available in module
import asyncio
