from rich.console import Console
import pytz

POLAND_TZ = pytz.timezone('Europe/Warsaw')
console = Console()

def print_banner():
    console.rule("[bold green]🚀 NutritionAI Backend Started[/bold green]")
    console.print(f"App Version: [magenta]0.0.1[/magenta]")
    console.print(f"Timezone: [yellow]{POLAND_TZ}[/yellow]")
    console.print(f"Admin Panel: [link=https://fiyouai.onrender.com]https://fiyouai.onrender.com[/link]")
    console.rule()

if __name__ == "__main__":
    print_banner()