# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Tools for the Focus & Flow ADHD Workplace Companion & Assistant."""

from typing import Any, Dict, List, Optional
from google.adk.tools import ToolContext


def micro_task_decomposer(
    task_description: str,
    energy_level: str = "medium",
    tool_context: Optional[ToolContext] = None,
) -> Dict[str, Any]:
    """Slices an overwhelming or vague task into concrete, low-activation-energy micro-steps.

    Args:
        task_description: The goal or task the user wants to accomplish.
        energy_level: User's current energy state ('low', 'medium', or 'high').
        tool_context: ToolContext for saving state across turns.

    Returns:
        A dictionary containing the starter action, numbered micro-steps (2-5 mins each),
        estimated completion time, and an encouraging body-doubling prompt.
    """
    energy = energy_level.lower()

    # In a full flow, this sets up the task schema for the LLM to populate and track
    result = {
        "status": "decomposed",
        "task": task_description,
        "energy_level": energy,
        "guidance": (
            "Present only the Starter Action (Step 1) first. Keep it strictly under 5 minutes. "
            "Ask the user to reply with 'done' or 'ready' when Step 1 is finished before giving Step 2."
        ),
    }

    if tool_context and hasattr(tool_context, "session") and tool_context.session:
        tool_context.session.state["active_task"] = {
            "name": task_description,
            "energy_level": energy,
            "current_step": 1,
            "completed_steps": [],
        }

    return result


def focus_session_tracker(
    action: str,
    task_name: Optional[str] = None,
    step_index: Optional[int] = None,
    duration_minutes: int = 25,
    tool_context: Optional[ToolContext] = None,
) -> Dict[str, Any]:
    """Manages focus sprints, logs micro-step completions, and tracks momentum.

    Args:
        action: The action to perform: 'start', 'complete_step', 'status', 'wrap_up'.
        task_name: Optional name of the active task.
        step_index: Optional index of the step being marked complete.
        duration_minutes: Duration of the focus block in minutes (default 25).
        tool_context: ToolContext for state persistence.

    Returns:
        Status dictionary with celebration message and current session metrics.
    """
    state_task: Dict[str, Any] = {}
    if tool_context and hasattr(tool_context, "session") and tool_context.session:
        state_task = tool_context.session.state.get("active_task", {})

    action_lower = action.lower()

    if action_lower == "start":
        effective_task = task_name or state_task.get("name", "Focus Session")
        if tool_context and hasattr(tool_context, "session") and tool_context.session:
            tool_context.session.state["focus_session"] = {
                "active": True,
                "task_name": effective_task,
                "duration_minutes": duration_minutes,
                "steps_completed": 0,
            }
        return {
            "status": "session_started",
            "task": effective_task,
            "target_duration_minutes": duration_minutes,
            "message": f"Focus sprint started for '{effective_task}' ({duration_minutes}m). I'm right here with you!",
        }

    elif action_lower == "complete_step":
        completed_step_num = step_index or state_task.get("current_step", 1)
        next_step = completed_step_num + 1

        if tool_context and hasattr(tool_context, "session") and tool_context.session:
            if "active_task" in tool_context.session.state:
                tool_context.session.state["active_task"]["current_step"] = next_step
                tool_context.session.state["active_task"].setdefault("completed_steps", []).append(completed_step_num)
            if "focus_session" in tool_context.session.state:
                tool_context.session.state["focus_session"]["steps_completed"] += 1

        return {
            "status": "step_completed",
            "completed_step": completed_step_num,
            "next_step": next_step,
            "reinforcement": "Awesome win! Every step builds momentum. Ready for the next one?",
        }

    elif action_lower == "wrap_up":
        completed_count = 0
        if tool_context and hasattr(tool_context, "session") and tool_context.session:
            session_data = tool_context.session.state.get("focus_session", {})
            completed_count = session_data.get("steps_completed", 0)
            tool_context.session.state["focus_session"] = {"active": False}

        return {
            "status": "session_completed",
            "total_steps_completed": completed_count,
            "message": f"Sprint wrapped up! You crushed {completed_count} micro-steps. Take a breath and hydrate!",
        }

    return {
        "status": "active",
        "task_name": state_task.get("name", "Current Task"),
        "current_step": state_task.get("current_step", 1),
    }


def daily_triage_organizer(
    raw_notes: str,
    tool_context: Optional[ToolContext] = None,
) -> Dict[str, Any]:
    """Triages messy brain-dump notes into Top-3 Must-Dos, Quick Wins (<5 min), and a Parking Lot.

    Args:
        raw_notes: Unstructured text of tasks, ideas, emails, and to-dos.
        tool_context: ToolContext for state persistence.

    Returns:
        Structured triage categories with guidance on starting the single highest-impact item.
    """
    if tool_context and hasattr(tool_context, "session") and tool_context.session:
        tool_context.session.state["last_brain_dump"] = raw_notes

    return {
        "status": "triaged",
        "instructions": (
            "Extract at most 3 'Top Must-Wins', identify any 'Quick Wins' (< 5 min), "
            "and place everything else in 'Parking Lot (Safe for Later)'. "
            "Highlight the single easiest first action to begin with."
        ),
        "raw_notes": raw_notes,
    }


def workplace_comms_drafter(
    format_type: str,
    context_notes: str,
    tone: str = "concise",
    tool_context: Optional[ToolContext] = None,
) -> Dict[str, Any]:
    """Generates crisp, workplace-ready communications (Standups, Slack messages, emails).

    Args:
        format_type: 'standup', 'slack_update', 'email', or 'meeting_notes'.
        context_notes: Bullet points or notes about what was done or needed.
        tone: Desired tone: 'professional', 'casual', 'concise'.
        tool_context: ToolContext for state persistence.

    Returns:
        Formatted communication template ready for user confirmation.
    """
    return {
        "status": "draft_ready",
        "format_type": format_type.lower(),
        "tone": tone.lower(),
        "notes": context_notes,
    }


def rabbit_hole_reset(
    derailment_description: str,
    tool_context: Optional[ToolContext] = None,
) -> Dict[str, Any]:
    """Provides non-judgmental recovery from hyperfocus derailment or task paralysis.

    Args:
        derailment_description: What distracted the user or where they feel stuck.
        tool_context: ToolContext for state persistence.

    Returns:
        Shame-free pivot instructions and a 60-second somatic reset prompt.
    """
    active_task = "your primary goal"
    if tool_context and hasattr(tool_context, "session") and tool_context.session:
        task_info = tool_context.session.state.get("active_task", {})
        if task_info and "name" in task_info:
            active_task = task_info["name"]

    return {
        "status": "reset_initiated",
        "primary_target": active_task,
        "derailment": derailment_description,
        "coaching_rule": (
            "1. Zero guilt or shame. Validate that ADHD brains seek novel stimulation when under-stimulated.\n"
            "2. Offer a quick physical break (shake hands, deep breath, drink water).\n"
            f"3. Guide back to '{active_task}' by asking for the single lowest-friction physical action (e.g. just opening the tab)."
        ),
    }
