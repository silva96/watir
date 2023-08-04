# frozen_string_literal: true

require 'watirspec_helper'

module Watir
  describe Browser do
    describe '#exists?' do
      it 'returns true if we are at a page' do
        browser.goto(WatirSpec.url_for('non_control_elements.html'))
        expect(browser).to exist
      end

      it 'returns false if window is closed',
         except: {browser: :safari,
                  reason: 'Clicking an Element that Closes a Window is returning NoMatchingWindowFoundException'},
         exclude: {browser: :ie,
                   reason: 'IE does not like switching windows'} do
        browser.goto WatirSpec.url_for('window_switching.html')
        browser.a(id: 'open').click
        browser.windows.wait_until(size: 2)
        browser.window(title: 'closeable window').use
        browser.a(id: 'close').click
        browser.windows.wait_until(size: 1)
        expect(browser.exists?).to be false
      ensure
        browser.windows.restore!
      end

      it 'returns false after Browser#close' do
        browser.close
        expect(browser).not_to exist
      end
    end

    describe '#closed?' do
      it 'returns false if not closed' do
        expect(browser).not_to be_closed
      end

      it 'returns false if window is closed but browser is not',
         except: {browser: :safari,
                  reason: 'Clicking an Element that Closes a Window is returning NoMatchingWindowFoundException'},
         exclude: {browser: :ie,
                   reason: 'IE Mode does not like closed windows'} do
        browser.goto WatirSpec.url_for('window_switching.html')
        browser.a(id: 'open').click
        browser.windows.wait_until(size: 2)
        browser.window(title: 'closeable window').use
        browser.a(id: 'close').click
        browser.windows.wait_until(size: 1)
        expect(browser).not_to be_closed
      ensure
        browser.windows.restore!
      end

      it 'returns false after Browser#close' do
        browser.close
        expect(browser).to be_closed
      end
    end

    describe '#html' do
      it 'returns the DOM of the page as an HTML string' do
        browser.goto(WatirSpec.url_for('right_click.html'))
        html = browser.html.downcase # varies between browsers

        expect(html).to match(/^<html/)
        expect(html).to include('<meta ')
        expect(html).to include(' content="text/html; charset=utf-8"')
        expect(html).to match(/http-equiv=("|)content-type/)
      end
    end

    describe '#status' do
      it 'returns the current value of window.status',
         except: {browser: :ie, reason: 'Status bar not enabled by default'} do
        browser.goto(WatirSpec.url_for('non_control_elements.html'))

        browser.execute_script "window.status = 'All done!';"
        expect(browser.status).to eq 'All done!'
      end
    end

    describe '#name' do
      it 'returns browser name' do
        expect(browser.name).to eq(WatirSpec.implementation.browser_name)
      end
    end

    describe '#send_key{,s}' do
      it 'sends keystrokes to the active element' do
        browser.goto WatirSpec.url_for 'forms_with_input_elements.html'

        browser.send_keys 'hello'
        expect(browser.text_field(id: 'new_user_first_name').value).to eq 'hello'
      end

      it 'sends keys to a frame' do
        browser.goto WatirSpec.url_for 'frames.html'
        tf = browser.frame.text_field(id: 'senderElement')
        tf.clear
        tf.click

        browser.frame.send_keys 'hello'

        expect(tf.value).to eq 'hello'
      end
    end

    describe '#text' do
      it 'returns the text of the page' do
        browser.goto(WatirSpec.url_for('non_control_elements.html'))
        expect(browser.text).to include('Dubito, ergo cogito, ergo sum.')
      end

      it 'returns the text also if the content-type is text/plain' do
        # more specs for text/plain? what happens if we call other methods?
        browser.goto(WatirSpec.url_for('plain_text'))
        expect(browser.text.strip).to eq 'This is text/plain'
      end

      it 'returns text of top most browsing context', except: {browser: :safari,
                                                               reason: 'Safari does not strip text'} do
        browser.goto(WatirSpec.url_for('nested_iframes.html'))
        browser.iframe(id: 'two').h3.exists?
        expect(browser.text).to eq 'Top Layer'
      end
    end

    describe '#url' do
      it 'returns the current url' do
        browser.goto(WatirSpec.url_for('non_control_elements.html'))
        expect(browser.url.casecmp(WatirSpec.url_for('non_control_elements.html'))).to eq 0
      end

      it 'always returns top url' do
        browser.goto(WatirSpec.url_for('frames.html'))
        browser.frame.body.exists? # switches to frame
        expect(browser.url.casecmp(WatirSpec.url_for('frames.html'))).to eq 0
      end
    end

    describe '#title' do
      it 'returns the current title' do
        browser.goto(WatirSpec.url_for('non_control_elements.html'))
        expect(browser.title).to eq 'Non-control elements'
      end

      it 'always returns top title' do
        browser.goto(WatirSpec.url_for('frames.html'))
        browser.element(tag_name: 'title').text
        browser.frame.body.exists? # switches to frame
        expect(browser.title).to eq 'Frames'
      end
    end

    # TODO: Temporarily disabling this before moving it to unit tests
    xdescribe '#new' do
      context 'when using parameters', except: {remote: true} do
        let(:url) { 'http://localhost:4544/wd/hub/' }

        before(:all) do
          @original = WatirSpec.implementation.clone

          require 'watirspec/remote_server'
          args = ["-Dwebdriver.chrome.driver=#{Webdrivers::Chromedriver.driver_path}",
                  "-Dwebdriver.gecko.driver=#{Webdrivers::Geckodriver.driver_path}"]
          WatirSpec::RemoteServer.new.start(4544, args: args)
          browser.close
        end

        before do
          @opts = WatirSpec.implementation.browser_args.last
        end

        after do
          @new_browser.close
          WatirSpec.implementation = @original.clone
        end

        it 'uses remote client based on provided url' do
          @opts[:url] = url
          @new_browser = WatirSpec.new_browser

          server_url = @new_browser.driver.instance_variable_get(:@bridge).http.instance_variable_get(:@server_url)
          expect(server_url).to eq URI.parse(url)
        end

        it 'sets client timeout' do
          @opts.merge!(url: url, open_timeout: 44, read_timeout: 47)
          @new_browser = WatirSpec.new_browser

          http = @new_browser.driver.instance_variable_get(:@bridge).http

          expect(http.open_timeout).to eq 44
          expect(http.read_timeout).to eq 47
        end

        it 'accepts http_client' do
          http_client = Selenium::WebDriver::Remote::Http::Default.new
          @opts[:url] = url
          @opts[:http_client] = http_client
          @new_browser = WatirSpec.new_browser

          expect(@new_browser.driver.instance_variable_get(:@bridge).http).to eq http_client
        end

        it 'accepts Remote::Capabilities instance as :desired_capabilities', only: {browser: :firefox} do
          caps = Selenium::WebDriver::Remote::Capabilities.firefox(accept_insecure_certs: true)
          @opts[:url] = url
          @opts[:desired_capabilities] = caps

          msg = /You can pass values directly into Watir::Browser opt without needing to use :desired_capabilities/
          expect { @new_browser = WatirSpec.new_browser }.to output(msg).to_stdout_from_any_process
          expect(@new_browser.driver.capabilities.accept_insecure_certs).to be true
        end

        it 'accepts individual driver capabilities', only: {browser: :firefox} do
          @opts[:accept_insecure_certs] = true
          @new_browser = WatirSpec.new_browser

          expect(@new_browser.driver.capabilities[:accept_insecure_certs]).to be true
        end

        it 'accepts profile', only: {browser: :firefox} do
          home_page = WatirSpec.url_for('special_chars.html')
          profile = Selenium::WebDriver::Firefox::Profile.new
          profile['browser.startup.homepage'] = home_page
          profile['browser.startup.page'] = 1
          @opts[:profile] = profile

          @new_browser = WatirSpec.new_browser

          expect(@new_browser.url).to eq home_page
        end

        context 'when using chrome arguments', only: {browser: :chrome} do
          it 'accepts browser options' do
            @opts[:options] = {emulation: {userAgent: 'foo;bar'}}

            @new_browser = WatirSpec.new_browser

            ua = @new_browser.execute_script 'return window.navigator.userAgent'
            expect(ua).to eq('foo;bar')
          end

          it 'uses remote client when specifying remote' do
            opts = {desired_capabilities: Selenium::WebDriver::Remote::Capabilities.chrome,
                    url: url}
            WatirSpec.implementation.browser_args = [:remote, opts]
            msg = /You can pass values directly into Watir::Browser opt without needing to use :desired_capabilities/
            expect { @new_browser = WatirSpec.new_browser }.to output(msg).to_stdout_from_any_process
            server_url = @new_browser.driver.instance_variable_get(:@bridge).http.instance_variable_get(:@server_url)
            expect(server_url).to eq URI.parse(url)
          end

          it 'accepts switches argument' do
            @opts.delete :args
            @opts[:switches] = ['--window-size=600,700']

            @new_browser = WatirSpec.new_browser
            size = @new_browser.window.size
            expect(size['height']).to eq 700
            expect(size['width']).to eq 600
          end

          it 'accepts Chrome::Options instance as :options', except: {headless: true} do
            chrome_opts = Selenium::WebDriver::Chrome::Options.new(emulation: {userAgent: 'foo;bar'})
            @opts.delete :args
            @opts[:options] = chrome_opts

            @new_browser = WatirSpec.new_browser

            ua = @new_browser.execute_script 'return window.navigator.userAgent'
            expect(ua).to eq('foo;bar')
          end
        end
      end

      it 'takes service as argument', only: {browser: :chrome} do
        @original = WatirSpec.implementation.clone
        browser.close
        @opts = WatirSpec.implementation.browser_args.last
        browser_name = WatirSpec.implementation.browser_args.first

        service = Selenium::WebDriver::Service.send(browser_name, port: '2314', args: ['foo'])

        @opts[:service] = service
        @opts[:listener] = LocalConfig::SelectorListener.new

        @new_browser = WatirSpec.new_browser

        bridge = @new_browser.wd.instance_variable_get(:@bridge)
        expect(bridge).to be_a Selenium::WebDriver::Support::EventFiringBridge
        service = @new_browser.wd.instance_variable_get(:@service)
        expect(service.instance_variable_get(:@extra_args)).to eq ['foo']
        expect(service.instance_variable_get(:@port)).to eq 2314

        @new_browser.close
      ensure
        WatirSpec.implementation = @original.clone
      end

      it 'takes a driver instance as argument' do
        mock_driver = instance_double(Selenium::WebDriver::Driver)
        allow(Selenium::WebDriver::Driver).to receive(:===).and_return(true)
        expect { described_class.new(mock_driver) }.not_to raise_error
        expect(Selenium::WebDriver::Driver).to have_received(:===).with(mock_driver)
      end

      it 'raises ArgumentError for invalid args' do
        expect { described_class.new(Struct.new) }.to raise_error(ArgumentError)
      end
    end

    describe '.start' do
      it 'goes to the given URL and return an instance of itself' do
        browser.close
        sleep 1
        driver, args = WatirSpec.implementation.browser_args
        b = described_class.start(WatirSpec.url_for('non_control_elements.html'), driver, args.dup)

        expect(b).to be_instance_of(described_class)
        expect(b.title).to eq 'Non-control elements'
        b.close
      end
    end

    describe '#goto' do
      it 'adds http:// to URLs with no URL scheme specified' do
        url = WatirSpec.host[%r{http://(.*)}, 1]
        expect(url).not_to be_nil
        browser.goto(url)
        expect(browser.url).to match(%r{http://#{url}/?})
      end

      it 'goes to the given url without raising errors' do
        expect { browser.goto(WatirSpec.url_for('non_control_elements.html')) }.not_to raise_error
      end

      it "goes to the url 'about:blank' without raising errors" do
        expect { browser.goto('about:blank') }.not_to raise_error
      end

      it 'goes to a data URL scheme address without raising errors' do
        expect { browser.goto('data:text/html;content-type=utf-8,foobar') }.not_to raise_error
      end

      it "goes to internal Chrome URL 'chrome://settings/browser' without raising errors",
         exclusive: {browser: %i[chrome edge]} do
        expect { browser.goto('chrome://settings/browser') }.not_to raise_error
      end

      it 'updates the page when location is changed with setTimeout + window.location' do
        browser.goto(WatirSpec.url_for('timeout_window_location.html'))
        browser.wait_while { |b| b.url.match?(/timeout_window_location|blank/) }
        expect(browser.url).to include('non_control_elements.html')
      end
    end

    describe '#refresh' do
      it 'refreshes the page' do
        browser.goto(WatirSpec.url_for('non_control_elements.html'))

        browser.div(id: 'best_language').scroll.to
        browser.div(id: 'best_language').click
        expect(browser.div(id: 'best_language').text).to include('Ruby!')
        browser.refresh
        browser.div(id: 'best_language').wait_until(&:present?)
        expect(browser.div(id: 'best_language').text).not_to include('Ruby!')
      end
    end

    describe '#execute_script' do
      before { browser.goto(WatirSpec.url_for('non_control_elements.html')) }

      it 'executes the given JavaScript on the current page' do
        expect(browser.pre(id: 'rspec').text).not_to eq 'javascript text'
        browser.execute_script("document.getElementById('rspec').innerHTML = 'javascript text'")
        expect(browser.pre(id: 'rspec').text).to eq 'javascript text'
      end

      it 'executes the given JavaScript in the context of an anonymous function' do
        expect(browser.execute_script('1 + 1')).to be_nil
        expect(browser.execute_script('return 1 + 1')).to eq 2
      end

      it 'returns correct Ruby objects' do
        expect(browser.execute_script('return {a: 1, "b": 2}')).to eq({'a' => 1, 'b' => 2})
        expect(browser.execute_script('return [1, 2, "3"]')).to contain_exactly(1, 2, '3')
        expect(browser.execute_script('return 1.2 + 1.3')).to eq 2.5
        expect(browser.execute_script('return 2 + 2')).to eq 4
        expect(browser.execute_script('return "hello"')).to eq 'hello'
        expect(browser.execute_script('return')).to be_nil
        expect(browser.execute_script('return null')).to be_nil
        expect(browser.execute_script('return undefined')).to be_nil
        expect(browser.execute_script('return true')).to be true
        expect(browser.execute_script('return false')).to be false
      end

      it 'works correctly with multi-line strings and special characters' do
        expect(browser.execute_script("//multiline rocks!
                            var a = 22; // comment on same line
                            /* more
                            comments */
                            var b = '33';
                            var c = \"44\";
                            return a + b + c")).to eq '223344'
      end

      it 'wraps elements as Watir objects' do
        returned = browser.execute_script('return document.body')
        expect(returned).to be_a(Watir::Body)
      end

      it 'wraps elements in an array' do
        list = browser.execute_script('return [document.body];')
        expect(list.size).to eq 1
        expect(list.first).to be_a(Watir::Body)
      end

      it 'wraps elements in a Hash' do
        hash = browser.execute_script('return {element: document.body};')
        expect(hash['element']).to be_a(Watir::Body)
      end

      it 'wraps elements in a deep object',
         except: {browser: %i[chrome edge],
                  reason: 'https://bugs.chromium.org/p/chromedriver/issues/detail?id=4536'} do
        hash = browser.execute_script('return {elements: [document.body], body: {element: document.body }}')

        expect(hash['elements'].first).to be_a(Watir::Body)
        expect(hash['body']['element']).to be_a(Watir::Body)
      end
    end

    describe '#back and #forward' do
      it 'goes to the previous page' do
        browser.goto WatirSpec.url_for('non_control_elements.html')
        orig_url = browser.url
        browser.goto WatirSpec.url_for('tables.html')
        new_url = browser.url
        expect(orig_url).not_to eq new_url
        browser.back
        expect(orig_url).to eq browser.url
      end

      it 'goes to the next page' do
        urls = []
        browser.goto WatirSpec.url_for('non_control_elements.html')
        urls << browser.url
        browser.goto WatirSpec.url_for('tables.html')
        urls << browser.url

        browser.back
        expect(browser.url).to eq urls.first
        browser.forward
        expect(browser.url).to eq urls.last
      end

      it 'navigates between several history items' do
        urls = ['non_control_elements.html',
                'tables.html',
                'forms_with_input_elements.html',
                'definition_lists.html'].map do |page|
          browser.goto WatirSpec.url_for(page)
          browser.url
        end

        3.times { browser.back }
        expect(browser.url).to eq urls.first
        2.times { browser.forward }
        expect(browser.url).to eq urls[2]
      end
    end

    it 'raises UnknownObjectException when trying to access DOM elements on plain/text-page' do
      browser.goto(WatirSpec.url_for('plain_text'))
      expect { browser.div(id: 'foo').id }.to raise_unknown_object_exception
    end

    it 'raises an error when trying to interact with a closed browser' do
      browser.goto WatirSpec.url_for 'definition_lists.html'
      browser.close

      expect { browser.dl(id: 'experience-list').id }.to raise_error(Watir::Exception::Error, 'browser was closed')
    end

    describe '#ready_state' do
      it "gets the document's readyState property" do
        allow(browser).to receive(:execute_script)
        browser.ready_state
        expect(browser).to have_received(:execute_script).with('return document.readyState')
      end
    end

    describe '#wait' do
      # The only way to get engage this method is with page load strategy set to "none"
      # This spec is both mocking out the response and demonstrating the necessary settings for it to be meaningful
      it 'waits for document ready state to be complete' do
        @original = WatirSpec.implementation.clone
        browser.close
        @opts = WatirSpec.implementation.browser_args.last

        @opts[:options] = {page_load_strategy: :none}
        browser = WatirSpec.new_browser

        start_time = ::Time.now
        allow(browser).to receive(:ready_state) { ::Time.now < start_time + 3 ? 'loading' : 'complete' }
        expect(browser.ready_state).to eq 'loading'

        browser.wait(20)
        expect(::Time.now - start_time).to be > 3
        expect(browser.ready_state).to eq 'complete'

        browser.close
      ensure
        WatirSpec.implementation = @original.clone
      end
    end

    describe '#inspect' do
      it 'works even if browser is closed' do
        allow(browser).to receive(:url).and_raise(Errno::ECONNREFUSED)
        expect { browser.inspect }.not_to raise_error
        expect(browser).to have_received(:url).once
      end
    end

    describe '#screenshot' do
      it 'returns an instance of of Watir::Screenshot' do
        expect(browser.screenshot).to be_a(Watir::Screenshot)
      end
    end
  end
end
