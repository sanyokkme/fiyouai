from rich.console import Console
import pytz

POLAND_TZ = pytz.timezone('Europe/Warsaw')
console = Console()

def print_banner():
    console.rule("[bold green]🚀 NutritionAI Backend Started[/bold green]")
    console.print(f"App Version: [magenta]0.0.1[/magenta]")
    console.print(f"Timezone: [yellow]{POLAND_TZ}[/yellow]")
    console.print(f"Admin Panel: [link=http://172.20.10.3:8000]http://172.20.10.3:8000[/link]")
    console.rule()

if __name__ == "__main__":
    print_banner()