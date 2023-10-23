import ora, {Ora} from 'ora';

class Spinner {
  private spinner: Ora | undefined;

  constructor() {}

  async init() {
    if (!this.spinner) {
      this.spinner = await ora({
        // make a singleton so we don't ever have 2 spinners
        spinner: 'dots',
      });
    }
    return this.spinner;
  }

  async updateSpinnerText(message: string) {
    const spinner = await this.init();
    if (spinner.isSpinning) {
      spinner.text = message;
      return;
    }
    spinner.start(message);
  }

  async stopSpinner() {
    const spinner = await this.init();
    if (spinner.isSpinning) {
      spinner.stop();
      console.log();
    }
  }

  async spinnerError(message?: string) {
    const spinner = await this.init();
    if (spinner.isSpinning) {
      spinner.fail(message);
    }
  }
  async spinnerSuccess(message?: string) {
    const spinner = await this.init();
    if (spinner.isSpinning) {
      spinner.succeed(message);
    }
  }
  async spinnerInfo(message: string) {
    const spinner = await this.init();
    spinner.info(message);
  }
  async space() {
    console.log();
  }
}

const spinners = new Spinner();

export default spinners;
